# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'yaml'
require_relative '../../scripts/check_dependency_security'

RSpec.describe DependencySecurity::Checker do
  around do |example|
    Dir.mktmpdir('archunit-security-spec') do |directory|
      @root = File.join(directory, 'project')
      @database = File.join(directory, 'database')
      FileUtils.mkdir_p([@root, File.join(@database, 'gems/rack')])
      File.write(File.join(@database, 'gems/rack/CVE-2099-0001.yml'), {
        'gem' => 'rack', 'cve' => '2099-0001', 'title' => 'Synthetic test advisory',
        'url' => 'https://example.invalid/test-advisory', 'date' => '2026-01-01',
        'description' => 'Test data, not a real vulnerability.', 'patched_versions' => ['>= 1.0.1']
      }.to_yaml)
      write_lock('1.0.1')
      example.run
    end
  end

  def write_lock(version)
    File.write(File.join(@root, 'Gemfile.lock'), <<~LOCK)
      GEM
        remote: https://rubygems.org/
        specs:
          rack (#{version})

      PLATFORMS
        ruby

      DEPENDENCIES
        rack (= #{version})
    LOCK
  end

  def checker(path = @database)
    described_class.new(root: @root, database_path: path)
  end

  it 'reports a clean lockfile only after a known-vulnerable fixture was detected' do
    report = checker.run(update: false)
    expect(report).to include(results: [], advisory_count: 1, vulnerable_fixture_detected: true)
  end

  it 'reports vulnerable locked versions without installing or loading them' do
    write_lock('1.0.0')
    expect(checker.run(update: false).fetch(:results)).not_to be_empty
    expect(Gem.loaded_specs.fetch('rack', nil)).to be_nil
  end

  it 'normalizes database separators on Windows before advisory globbing' do
    skip 'Windows path syntax' unless Gem.win_platform?

    expect(checker(@database.tr('/', '\\')).run(update: false).fetch(:advisory_count)).to eq(1)
  end

  it 'rejects an empty database rather than reporting clean' do
    File.delete(File.join(@database, 'gems/rack/CVE-2099-0001.yml'))
    expect { checker.run(update: false) }.to raise_error(/database is empty/)
  end

  it 'rejects a database that cannot detect the known-vulnerable health fixture' do
    FileUtils.mkdir_p(File.join(@database, 'gems/other'))
    FileUtils.move(File.join(@database, 'gems/rack/CVE-2099-0001.yml'),
                   File.join(@database, 'gems/other/CVE-2099-0001.yml'))
    expect { checker.run(update: false) }.to raise_error(/missed a known-vulnerable/)
  end

  it 'never downloads a database during an explicitly offline scan' do
    expect(Bundler::Audit::Database).not_to receive(:download)
    expect { checker(File.join(@database, 'missing')).run(update: false) }
      .to raise_error(/offline scan/)
  end

  it 'fails closed when an update is skipped or fails' do
    allow_any_instance_of(Bundler::Audit::Database).to receive(:update!).and_return(nil)
    expect { checker.run }.to raise_error(/update did not complete/)
    allow_any_instance_of(Bundler::Audit::Database).to receive(:update!).and_raise(
      Bundler::Audit::Database::UpdateFailed, 'network failed'
    )
    expect { checker.run }.to raise_error(/network failed/)
  end

  it 'keeps security checks read-only, bounded, scheduled, and preserves failure evidence' do
    workflow = YAML.safe_load_file(
      File.expand_path('../../.github/workflows/security.yml', __dir__)
    )
    expect(workflow.fetch('permissions')).to eq('contents' => 'read')
    job = workflow.fetch('jobs').fetch('audit')
    expect(job.fetch('timeout-minutes')).to eq(10)
    expect(job).not_to have_key('env')
    scan = job.fetch('steps').find do |step|
      step['run'] == 'bundle exec ruby scripts/check_dependency_security.rb'
    end
    expect(scan.fetch('env')).to have_key('BUNDLER_AUDIT_DB')
    expect(job.fetch('steps')).to include(include('if' => 'always()'))
    triggers = workflow['on'] || workflow[true]
    expect(triggers).to include('pull_request', 'workflow_dispatch', 'schedule')
  end
end

RSpec.describe DependencySecurity do
  around do |example|
    Dir.mktmpdir('archunit-audit-evidence') do |root|
      @output = File.join(root, 'report.json')
      example.run
    end
  end

  [[], [{ 'type' => 'unpatched_gem' }]].each do |findings|
    it "returns the correct exit code and persists #{findings.length} findings" do
      report = { results: findings, advisory_count: 1 }
      checker = instance_double(DependencySecurity::Checker, run: report)
      allow(DependencySecurity::Checker).to receive(:new).and_return(checker)
      status = nil

      expect { status = described_class.execute(['--no-update', '--output', @output]) }
        .to output(/#{findings.length} findings/).to_stdout
      expect(status).to eq(findings.empty? ? 0 : 1)
      expect(JSON.parse(File.read(@output)).fetch('results')).to eq(findings)
    end
  end

  it 'fails and persists diagnostic evidence on scanner errors' do
    allow(DependencySecurity::Checker).to receive(:new).and_raise('update failed')
    status = nil
    expect { status = described_class.execute(['--output', @output]) }
      .to output(/update failed/).to_stderr
    expect(status).to eq(1)
    expect(JSON.parse(File.read(@output)).fetch('error')).to include('update failed')
  end
end
