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
  let(:matrix) { job.fetch('strategy').fetch('matrix').fetch('include') }
  let(:steps) { job.fetch('steps') }

  it 'tests every supported CRuby line and current Ruby on Windows' do
    expect(matrix).to contain_exactly(
      { 'os' => 'ubuntu-latest', 'ruby' => '3.3' },
      { 'os' => 'ubuntu-latest', 'ruby' => '3.4' },
      { 'os' => 'ubuntu-latest', 'ruby' => '4.0' },
      { 'os' => 'windows-latest', 'ruby' => '4.0' }
    )
  end

  it 'runs the repository gate and builds the gem' do
    commands = steps.filter_map { |step| step['run'] }

    expect(commands).to include('bundle exec rake', 'gem build archunit.gemspec')
  end

  it 'uses read-only repository permissions and non-blocking matrix failures' do
    expect(workflow.fetch('permissions')).to eq('contents' => 'read')
    expect(job.fetch('strategy').fetch('fail-fast')).to be(false)
  end
end
