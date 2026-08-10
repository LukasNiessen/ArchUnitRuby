# frozen_string_literal: true

require 'yaml'

RSpec.describe 'Dependabot configuration' do
  subject(:updates) do
    path = File.expand_path('../../.github/dependabot.yml', __dir__)
    YAML.safe_load_file(path).fetch('updates')
  end

  it 'checks Ruby and GitHub Actions dependencies every week' do
    ecosystems = updates.to_h do |update|
      [update.fetch('package-ecosystem'), update.fetch('schedule').fetch('interval')]
    end

    expect(ecosystems).to eq('bundler' => 'weekly', 'github-actions' => 'weekly')
  end
end
