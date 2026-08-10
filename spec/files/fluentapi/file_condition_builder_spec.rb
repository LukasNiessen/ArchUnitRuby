# frozen_string_literal: true

require 'pathname'

RSpec.describe ArchUnit::Files::FluentApi::FileConditionBuilder do
  def matches?(path, builder)
    ArchUnit::PatternMatching.matches_all_patterns?(path, builder.filters)
  end

  it 'starts with an optional immutable project locator and no filters' do
    locator = +'example/Gemfile'
    builder = ArchUnit.project_files(locator)
    locator.replace('changed')

    expect(builder).to be_a(described_class)
    expect(builder.project_locator).to eq('example/Gemfile')
    expect(builder.project_locator).to be_frozen
    expect(builder.filters).to eq([])
    expect(builder.filters).to be_frozen
    expect(builder).to be_frozen
  end

  it 'accepts path-like project locators and exposes the files alias' do
    locator = Pathname.new('example')

    expect(ArchUnit.files(locator).project_locator).to eq('example')
    expect(ArchUnit::Files::FluentApi.files(locator).project_locator).to eq('example')
  end

  it 'selects by filename, folder, path, and exact file' do
    named = ArchUnit.project_files.with_name('*_service.rb')
    folder = ArchUnit.project_files.in_folder('lib/**/service')
    path = ArchUnit.project_files.in_path('lib/**/*.rb')
    file = ArchUnit.project_files.in_file('lib/order[legacy].rb')

    expect(matches?('lib/orders/order_service.rb', named)).to be(true)
    expect(matches?('lib/orders/order.rb', named)).to be(false)
    expect(matches?('lib/orders/service/order.rb', folder)).to be(true)
    expect(matches?('spec/orders/service/order_spec.rb', folder)).to be(false)
    expect(matches?('lib/orders/order.rb', path)).to be(true)
    expect(matches?('spec/orders/order_spec.rb', path)).to be(false)
    expect(matches?('lib/order[legacy].rb', file)).to be(true)
    expect(matches?('lib/orderl.rb', file)).to be(false)
  end

  it 'combines chained selectors with AND semantics' do
    builder = ArchUnit
              .project_files
              .in_folder('lib/**/service')
              .with_name('*_service.rb')
              .in_path('lib/orders/**')

    expect(matches?('lib/orders/service/order_service.rb', builder)).to be(true)
    expect(matches?('lib/billing/service/billing_service.rb', builder)).to be(false)
    expect(matches?('lib/orders/service/order_repository.rb', builder)).to be(false)
  end

  it 'branches without mutating the reusable base scope' do
    base = ArchUnit.project_files('example').in_folder('lib/**')
    services = base.with_name('*_service.rb')
    repositories = base.with_name('*_repository.rb')

    expect(base.filters.length).to eq(1)
    expect(services.filters.length).to eq(2)
    expect(repositories.filters.length).to eq(2)
    expect(matches?('lib/orders/order_service.rb', services)).to be(true)
    expect(matches?('lib/orders/order_repository.rb', repositories)).to be(true)
    expect(services.filters).not_to equal(repositories.filters)
  end

  it 'rejects invalid locators, selectors, and injected filter state' do
    expect { ArchUnit.project_files('') }
      .to raise_error(ArgumentError, /project_locator/)
    expect { ArchUnit.project_files.with_name(123) }
      .to raise_error(ArgumentError, /String glob or Regexp/)
    expect { ArchUnit.project_files.in_file('') }
      .to raise_error(ArgumentError, /non-empty String/)
    expect { described_class.new(filters: [Object.new]) }
      .to raise_error(ArgumentError, /only Filter/)
  end
end
