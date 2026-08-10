# frozen_string_literal: true

require 'yaml'

RSpec.describe 'the CI workflow' do
  subject(:workflow) do
    YAML.safe_load_file(
      File.expand_path('../../.github/workflows/ci.yml', __dir__),
      aliases: true
    )
  end

  let(:job) { workflow.fetch('jobs').fetch('test') }
  let(:quality_job) { workflow.fetch('jobs').fetch('quality') }
  let(:fixture_job) { workflow.fetch('jobs').fetch('rag-fixture') }
  let(:matrix) { job.fetch('strategy').fetch('matrix').fetch('include') }
  let(:steps) { job.fetch('steps') }

  it 'tests older supported CRuby lines and current Ruby on Windows' do
    expect(matrix).to contain_exactly(
      { 'os' => 'ubuntu-latest', 'ruby' => '3.3' },
      { 'os' => 'ubuntu-latest', 'ruby' => '3.4' },
      { 'os' => 'windows-latest', 'ruby' => '4.0' }
    )
  end

  it 'runs only compatibility tests in the platform matrix' do
    commands = steps.filter_map { |step| step['run'] }

    expect(commands).to include('bundle exec rspec')
    expect(commands).not_to include('bundle exec rubocop', 'bundle exec rake build')
  end

  it 'runs coverage, lint, package build, and installed-gem smoke tests once' do
    quality_steps = quality_job.fetch('steps')
    ruby_setup = quality_steps.find { |step| step['uses'] == 'ruby/setup-ruby@v1' }
    coverage_step = quality_steps.find { |step| step['name'] == 'Test with coverage' }
    commands = quality_steps.filter_map { |step| step['run'] }.join("\n")

    expect(coverage_step.fetch('env')).to eq('COVERAGE' => 'true')
    expect(commands).to include(
      'bundle exec rspec', 'bundle exec rubocop',
      'gem build archunit.gemspec --strict --output pkg/archunit.gem',
      'gem install pkg/archunit.gem', "require 'archunit'", 'ArchUnit.project_files',
      'depend_on_files', 'depend_on_external_modules', "matching('json')",
      'adhere_to', 'file.extension', 'ArchUnit::Checkable',
      'ArchUnit.assert_passes', 'ArchUnit.format_violations',
      'ArchUnit.project_layers', "layer('library')", "where_layer('library')",
      'may_only_depend_on_layers', 'ArchUnit.project_graph',
      'include_external_dependencies', 'collapse_to_folder_depth',
      'ArchUnit::GraphReportSnapshot', 'JSON.parse', 'to_csv', 'export_as_html'
    )
    expect(quality_job.fetch('runs-on')).to eq('ubuntu-latest')
    expect(ruby_setup.fetch('with').fetch('ruby-version')).to eq('4.0')
  end

  it 'smoke-tests both optional native framework integrations' do
    adapter_step = quality_job.fetch('steps').find do |step|
      step['name'] == 'Smoke optional framework integrations'
    end
    command = adapter_step.fetch('run')

    expect(command).to include(
      "require 'rspec/expectations'", 'include RSpec::Matchers', 'expect(rule).to pass',
      "require 'minitest'", 'include Minitest::Assertions',
      'context.assert_passes(rule)', 'context.assertions == 1'
    )
  end

  it 'uses read-only repository permissions and non-blocking matrix failures' do
    expect(workflow.fetch('permissions')).to eq('contents' => 'read')
    expect(job.fetch('strategy').fetch('fail-fast')).to be(false)
  end

  it 'bounds every job so a hung runner cannot consume capacity indefinitely' do
    expect(workflow.fetch('jobs').values).to all(include('timeout-minutes' => 10))
  end

  it 'locks dependencies for both CI operating-system families' do
    lockfile = File.read(File.expand_path('../../Gemfile.lock', __dir__))

    expect(lockfile).to include("  x64-mingw-ucrt\n", "  x86_64-linux\n")
  end

  it 'runs the public RAG fixture against the revision under test' do
    fixture_steps = fixture_job.fetch('steps')
    checkout = fixture_steps.find do |step|
      step.dig('with', 'repository') == 'TristanKruse/ArchUnitRuby-TestRepo-RAG'
    end
    test_step = fixture_steps.find { |step| step['run'] == 'bundle exec rake' }

    expect(checkout).not_to be_nil
    expect(test_step).to include('working-directory' => 'ArchUnitRuby-TestRepo-RAG')
  end
end
