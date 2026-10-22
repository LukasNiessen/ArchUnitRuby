# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative '../../benchmark/real_world_canary'

RSpec.describe RealWorldCanary::Runner do
  let(:revision) { 'a' * 40 }
  let(:project) do
    { 'repository' => 'example/fixture', 'revision' => revision,
      'witness' => { 'source' => 'api.rb', 'target' => 'store.rb' },
      'modes' => {
        'imports' => expected_snapshot(['require_relative']),
        'imports_and_constants' => expected_snapshot(%w[constant_reference require_relative])
      } }
  end

  around do |example|
    Dir.mktmpdir('archunit-canary-spec') do |root|
      @root = File.realpath(root)
      FileUtils.mkdir_p(File.join(@root, 'lib'))
      File.write(File.join(@root, 'Gemfile'), "raise 'must never execute'\n")
      File.write(File.join(@root, 'lib/api.rb'), <<~RUBY)
        require_relative 'store'
        class Api
          def call = ::Store.new
        end
      RUBY
      File.write(File.join(@root, 'lib/store.rb'), "raise 'must never execute'\nclass Store; end\n")
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  before do
    status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).and_return([revision, '', status])
    allow(Open3).to receive(:capture3).with(
      { 'GIT_OPTIONAL_LOCKS' => '0' }, 'git', '-C', @root,
      'status', '--porcelain', '--untracked-files=normal', '--', 'lib'
    ).and_return(['', '', status])
  end

  def expected_snapshot(kinds)
    graph_data = [%w[api.rb store.rb], [['api.rb', 'store.rb', kinds]]]
    { 'file_count' => 2, 'internal_dependencies' => 1, 'external_dependencies' => 0,
      'internal_graph_sha256' => Digest::SHA256.hexdigest(JSON.generate(graph_data)) }
  end

  def run_canary(record: false)
    described_class.new(root: @root, project:).run(record:)
  end

  it 'checks both modes, cache reuse, and pass/fail rules without executing source' do
    result = run_canary
    expect(result).to include(baseline_verified: true, source_directory: 'lib')
    expected = { passing_rule: true, forbidden_rule_violations: 1,
                 performance: include(graph_cache_reused: true) }
    expect(result.fetch(:modes).values).to all(include(expected))
  end

  it 'fails on changed counts and missing or changed graph fingerprints' do
    project['modes']['imports']['file_count'] = 3
    expect { run_canary }.to raise_error(/graph changed/)
    project['modes']['imports'] = expected_snapshot(['require_relative'])
    project['modes']['imports']['internal_graph_sha256'] = '0' * 64
    expect { run_canary }.to raise_error(/graph changed/)
  end

  it 'does not silently bless missing baselines except in explicit observation mode' do
    project.delete('modes')
    expect { run_canary }.to raise_error(KeyError)
    expect(run_canary(record: true).fetch(:baseline_verified)).to be(false)
    expect(project).not_to have_key('modes')
  end

  it 'rejects the wrong revision and mutable ref names' do
    project['revision'] = 'main'
    expect { run_canary }.to raise_error(/immutable commit/)
    project['revision'] = 'b' * 40
    expect { run_canary }.to raise_error(/revision does not match/)
  end

  it 'rejects dirty library sources and failed git inspection' do
    status = instance_double(Process::Status, success?: true)
    allow(Open3).to receive(:capture3).with(
      { 'GIT_OPTIONAL_LOCKS' => '0' }, 'git', '-C', @root,
      'status', '--porcelain', '--untracked-files=normal', '--', 'lib'
    ).and_return([' M lib/api.rb', '', status])
    expect { run_canary }.to raise_error(/source must be clean/)
    allow(Open3).to receive(:capture3).and_return(
      ['', 'not a repository', instance_double(Process::Status, success?: false)]
    )
    expect { run_canary }.to raise_error(/Could not inspect corpus/)
  end

  it 'rejects a missing witness instead of treating zero violations as success' do
    project['witness']['target'] = 'missing.rb'
    expect { run_canary }.to raise_error(/Expected one known forbidden/)
  end

  it 'detects a regression that disables warm graph reuse' do
    runner = instance_double(ExtractionBenchmark::Runner, run: { graph_cache_reused: false })
    allow(ExtractionBenchmark::Runner).to receive(:new).and_return(runner)
    expect { run_canary }.to raise_error(/Warm analysis/)
  end

  it 'refuses a canonical lib directory outside the corpus' do
    source = File.join(@root, 'lib')
    allow(File).to receive(:realpath).and_call_original
    allow(File).to receive(:realpath).with(source).and_return(File.dirname(@root))
    expect { run_canary }.to raise_error(/source directory must stay inside/)
  end

  it 'does not accept a forbidden assertion that unexpectedly passes' do
    allow(ArchUnit).to receive(:assert_passes).and_return(nil)
    expect { run_canary }.to raise_error(/forbidden architecture assertion unexpectedly passed/)
  end

  it 'requires assertion failures to retain the rule rationale' do
    allow(ArchUnit).to receive(:assert_passes).and_wrap_original do |original, *arguments|
      original.call(*arguments)
    rescue ArchUnit::AssertionFailure => e
      allow(e).to receive(:message).and_return('missing rationale')
      raise
    end
    expect { run_canary }.to raise_error(/Failure omitted rule rationale/)
  end

  def cli_arguments
    manifest = File.join(@root, 'manifest.json')
    File.write(manifest, JSON.generate('projects' => { 'fixture' => project }))
    ['--project', 'fixture', '--root', @root, '--manifest', manifest,
     '--output', File.join(@root, 'reports/canary.json')]
  end

  it 'writes verified CLI evidence and returns a successful exit status' do
    status = nil
    expect do
      status = RealWorldCanary.execute(cli_arguments)
    end.to output(/baseline_verified/).to_stdout
    expect(status).to eq(0)
    report = JSON.parse(File.read(File.join(@root, 'reports/canary.json')))
    expect(report).to include('baseline_verified' => true, 'revision' => revision)
  end

  it 'records observations only when explicitly requested and never changes the manifest' do
    project.delete('modes')
    arguments = cli_arguments
    manifest = File.read(File.join(@root, 'manifest.json'))
    status = nil
    expect do
      status = RealWorldCanary.execute(arguments + ['--record'])
    end.to output(/"baseline_verified": false/).to_stdout
    expect(status).to eq(0)
    expect(File.read(File.join(@root, 'manifest.json'))).to eq(manifest)
  end

  it 'persists CLI failure evidence and returns a failing exit status' do
    project['revision'] = 'b' * 40
    status = nil
    expect do
      status = RealWorldCanary.execute(cli_arguments)
    end.to output(/revision does not match/).to_stderr
    expect(status).to eq(1)
    report = JSON.parse(File.read(File.join(@root, 'reports/canary.json')))
    expect(report.fetch('error')).to include('revision does not match')
  end

  it 'fails closed on unknown options and unexpected positional arguments' do
    status = nil
    expect do
      status = RealWorldCanary.execute(['--invalid'])
    end.to output(/invalid option/).to_stderr
    expect(status).to eq(1)
    expect do
      status = RealWorldCanary.execute(['unexpected'])
    end.to output(/Unexpected positional arguments/).to_stderr
    expect(status).to eq(1)
  end
end

RSpec.describe 'Real-world canary workflow' do
  it 'pins the same immutable corpus revisions in workflow and reviewed manifest' do
    root = File.expand_path('../..', __dir__)
    manifest = File.read(File.join(root, 'benchmark/canary/projects.json'))
    projects = JSON.parse(manifest).fetch('projects')
    workflow = YAML.safe_load_file(File.join(root, '.github/workflows/canary.yml'))
    job = workflow.fetch('jobs').fetch('canary')
    entries = job.fetch('strategy').fetch('matrix').fetch('include')
    expect(entries.map { |item| item.fetch('name') }).to match_array(projects.keys)
    entries.each do |entry|
      expected = projects.fetch(entry.fetch('name'))
      expect(entry).to include(expected.slice('repository', 'revision'))
    end
    expect(workflow.fetch('permissions')).to eq('contents' => 'read')
    expect(job.fetch('timeout-minutes')).to eq(10)
    commands = job.fetch('steps').filter_map { |step| step['run'] }.join("\n")
    expect(commands).not_to include('--record', 'bundle install', 'rspec', 'rake')
    triggers = workflow['on'] || workflow[true]
    expect(triggers).to include('workflow_dispatch', 'pull_request')
    expect(triggers).not_to include('schedule')
  end
end
