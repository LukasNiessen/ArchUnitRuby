# frozen_string_literal: true

require 'archunit/cli'
require 'json'
require 'stringio'
require 'tmpdir'
require 'fileutils'

RSpec.describe ArchUnit::CLI do
  around do |example|
    Dir.mktmpdir('archunit-cli-project') do |directory|
      @root = directory
      @config = File.join(directory, '.archunit.rb')
      FileUtils.mkdir_p(File.join(directory, 'app/api'))
      FileUtils.mkdir_p(File.join(directory, 'app/db'))
      File.write(File.join(directory, 'Gemfile'), "raise 'Do not evaluate target Gemfile'")
      File.write(File.join(directory, 'project.gemspec'), "raise 'Do not evaluate target gemspec'")
      File.write(File.join(directory, 'app/api/request.rb'), "raise 'Do not execute target source'")
      File.write(File.join(directory, 'app/db/settings.rb'), 'module Db; DEFAULT ||= 42; end')
      write_config
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  def write_config
    File.write(@config, <<~RUBY)
      rule 'API stays out of storage' do
        project_files.in_path('app/api/**').should_not.depend_on_files
          .in_path('app/db/**').because('Keep storage private')
      end
    RUBY
  end

  def invoke(*arguments, cwd: @root)
    output = StringIO.new
    errors = StringIO.new
    code = described_class.run(arguments, out: output, err: errors, cwd:)
    [code, output.string, errors.string]
  end

  def json_check(*arguments)
    code, output, errors = invoke('check', '--format', 'json', *arguments)
    expect(errors).to eq('')
    [code, JSON.parse(output)]
  end

  it 'passes in text mode without executing a target Gemfile, gemspec, or source' do
    code, output, errors = invoke('check')

    expect(code).to eq(0)
    expect(output).to include('[passed] API stays out of storage', 'Because: Keep storage private')
    expect(errors).to eq('')
  end

  it 'reports a failing import after a source edit, including rationale and versioned JSON' do
    expect(json_check.first).to eq(0)
    File.write(File.join(@root, 'app/api/request.rb'), "require_relative '../db/settings'")
    code, payload = json_check

    expect(code).to eq(1)
    expect(payload).to include('schema_version' => 1, 'status' => 'failed')
    expect(payload['summary']).to eq('rule_count' => 1, 'violation_count' => 1)
    rule = payload['rules'].first
    expect(rule).to include('rationale' => 'Keep storage private', 'status' => 'failed')
    expect(rule['violations'].first).to include(
      'type' => 'ArchUnit::Files::Assertion::FileDependencyViolation',
      'message' => 'File dependency violation',
      'details' => include('app/api/request.rb', 'app/db/settings.rb')
    )
  end

  it 'renders shared violation wording in text output' do
    File.write(File.join(@root, 'app/api/request.rb'), "require_relative '../db/settings'")
    code, output, errors = invoke

    expect(code).to eq(1)
    expect(output).to include('File dependency violation', 'depends on forbidden file')
    expect(errors).to eq('')
  end

  it 'preserves import-only defaults and explicitly opts into conditional constant references' do
    File.write(File.join(@root, 'app/api/request.rb'), '::Db::DEFAULT')

    expect(json_check.first).to eq(0)
    code, payload = json_check('--dependency-analysis', 'imports_and_constants')
    expect(code).to eq(1)
    expect(payload['dependency_analysis']).to eq('imports_and_constants')
  end

  it 'does not silently pass a selector matching no files' do
    File.write(@config, "rule('typo') { project_files.in_path('absent/**').should.have_no_cycles }")
    code, payload = json_check

    expect(code).to eq(1)
    expect(payload.dig('rules', 0, 'violations', 0, 'type')).to eq('ArchUnit::Common::Assertion::EmptyTestViolation')
  end

  it 'reports structured parse diagnostics with a technical-error status, not a rule violation' do
    File.write(File.join(@root, 'app/db/settings.rb'), 'class Broken <')
    code, payload = json_check

    expect(code).to eq(2)
    expect(payload).to include('status' => 'error')
    expect(payload['error']).to include('type' => 'ArchUnit::SourceParseError',
                                        'rule_name' => 'API stays out of storage')
    expect(payload.dig('error', 'diagnostics').first).to include(
      'path' => include('settings.rb'), 'line' => 1, 'column' => be_positive,
      'message' => be_a(String)
    )
  end

  it 'checks every rule and preserves completed results if a later rule raises' do
    File.open(@config, 'a') do |file|
      file.puts "rule('missing') { project_files.in_path('missing/**').should.have_no_cycles }"
    end
    code, payload = json_check
    expect(code).to eq(1)
    expect(payload['rules'].map { |rule| rule['status'] }).to eq(%w[passed failed])

    File.open(@config, 'a') do |file|
      file.puts "rule('broken') { project_files.should.adhere_to(" \
                "->(_file) { raise 'custom failure' }, 'custom') }"
    end
    code, payload = json_check
    expect(code).to eq(2)
    expect(payload.dig('error', 'rule_name')).to eq('broken')
    expect(payload['rules'].length).to eq(2)
  end

  it 'honors project exclusions' do
    File.write(File.join(@root, 'app/api/request.rb'), '::Db::DEFAULT')
    File.write(File.join(@root, '.archignore'), "app/db/\n")

    expect(json_check('--dependency-analysis', 'imports_and_constants').first).to eq(0)
  end

  it 'explains configured names and rationale without parsing malformed target source' do
    File.write(File.join(@root, 'app/api/request.rb'), 'class Broken <')
    expect(Prism).not_to receive(:parse)
    code, output, errors = invoke('explain', '--format=json')
    payload = JSON.parse(output)

    expect(code).to eq(0)
    expect(payload['status']).to eq('configured')
    expect(payload.dig('rules', 0, 'status')).to eq('not_checked')
    expect(payload.dig('rules', 0, 'rationale')).to eq('Keep storage private')
    expect(errors).to eq('')
  end

  it 'clearly labels text explanations as not evaluated' do
    code, output, = invoke('explain')

    expect(code).to eq(0)
    expect(output).to include('not evaluated', '[not_checked] API stays out of storage')
  end

  it 'uses an explicit config and root even when invoked from elsewhere' do
    custom = File.join(@root, 'custom.rb')
    FileUtils.mv(@config, custom)
    code, output, errors = invoke('check', '--project', @root, '--config', custom,
                                  cwd: File.dirname(@root))

    expect(code).to eq(0)
    expect(output).to include(@root, custom)
    expect(errors).to eq('')
  end

  it 'handles help and version without loading configuration' do
    File.write(@config, "raise 'Do not load configuration for informational commands'")

    expect(invoke('--help')[0..1]).to match([0, include('Usage:', '--dependency-analysis')])
    expect(invoke('--version')[0..1]).to eq([0, "#{ArchUnit::VERSION}\n"])
  end

  it 'reports missing configuration as an error on stderr in text mode' do
    FileUtils.rm_f(@config)
    code, output, errors = invoke('check')

    expect(code).to eq(2)
    expect(output).to eq('')
    expect(errors).to include('ArchUnit error:', '.archunit.rb')
  end

  ['# no rules', 'exit 0', 'rule(', "raise 'bad configuration'",
   "require 'archunit_missing_cli_dependency'",
   "rule('incomplete') { project_files }", "rule('name')", "rule('') { nil }"].each do |source|
    it "does not pass invalid configuration #{source.inspect}" do
      File.write(@config, source)
      code, payload = json_check

      expect(code).to eq(2)
      expect(payload['status']).to eq('error')
      expect(payload['error']['message']).not_to be_empty
    end
  end

  it 'rejects unknown flags as JSON even before the output-format flag' do
    code, output, errors = invoke('check', '--unknown', '--format=json')

    expect(code).to eq(2)
    expect(JSON.parse(output).dig('error', 'type')).to eq('OptionParser::InvalidOption')
    expect(errors).to eq('')
  end

  it 'initializes an explicit destination with a usable cycle-check starter' do
    destination = File.join(@root, 'new-config.rb')
    code, output, errors = invoke('init', '--config', destination)
    expect(code).to eq(0)
    expect(output).to include('initialized', 'trusted Ruby configuration')
    expect(errors).to eq('')
    expect(File.read(destination)).to include('have_no_cycles', 'lib/**/*.rb')

    FileUtils.mkdir_p(File.join(@root, 'lib'))
    File.write(File.join(@root, 'lib/clean.rb'), 'class Clean; end')
    expect(invoke('check', '--config', destination).first).to eq(0)
  end

  it 'never overwrites an existing configuration or directory' do
    original = File.binread(@config)

    expect(invoke('init').first).to eq(2)
    expect(File.binread(@config)).to eq(original)
    expect(invoke('init', '--config', File.join(@root, 'app')).first).to eq(2)
    expect(File.directory?(File.join(@root, 'app'))).to be(true)
  end

  it 'never follows or replaces a dangling configuration symlink during init' do
    link = File.join(@root, 'linked-config.rb')
    target = File.join(@root, 'missing-config.rb')
    begin
      File.symlink(target, link)
    rescue NotImplementedError, Errno::EPERM, Errno::EACCES
      skip 'creating symlinks is not available for this user or platform'
    end

    expect(invoke('init', '--config', link).first).to eq(2)
    expect(File.symlink?(link)).to be(true)
    expect(File.exist?(target)).to be(false)
  end
end
