# frozen_string_literal: true

require 'pathname'

RSpec.describe 'the ArchUnitRuby gem specification' do
  subject(:specification) do
    Gem::Specification.load(File.expand_path('../../archunit.gemspec', __dir__))
  end

  it 'declares MIT licensing and packages the license text' do
    expect(specification.licenses).to eq(['MIT'])
    expect(specification.files).to include('LICENSE')
  end

  it 'packages every library source file' do
    expected_sources = Dir[File.expand_path('../../lib/**/*.rb', __dir__)].map do |path|
      Pathname.new(path).relative_path_from(Pathname.new(File.expand_path('../..', __dir__))).to_s
    end

    expect(specification.files).to include(*expected_sources)
  end

  it 'declares every library needed by a clean installed graph renderer' do
    dependencies = specification.runtime_dependencies.to_h do |dependency|
      [dependency.name, dependency.requirement.to_s]
    end

    expect(dependencies).to include(
      'csv' => '>= 3.3, < 4.0',
      'json' => '>= 2.7, < 3.0',
      'prism' => '>= 1.0, < 2.0'
    )
  end
end
