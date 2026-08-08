# frozen_string_literal: true

RSpec.describe ArchUnit::Common::PatternMatching do
  def filter(regexp, target:, matching: :partial, exclusions: [])
    ArchUnit::Common::Filter.new(regexp:, target:, matching:, exclusions:)
  end

  it 'normalizes paths and extracts their filename and folder' do
    expect(described_class.normalize_path('lib\\domain/service.rb'))
      .to eq('lib/domain/service.rb')
    expect(described_class.extract_filename('lib\\domain/service.rb')).to eq('service.rb')
    expect(described_class.path_without_filename('lib\\domain/service.rb')).to eq('lib/domain')
  end

  it 'selects the filename target from the filter' do
    matcher = filter(/\Aservice\.rb\z/, target: :filename)

    expect(described_class.matches_pattern?('lib/domain/service.rb', matcher)).to be(true)
  end

  it 'selects and normalizes the path target from the filter' do
    matcher = filter(%r{\Alib/domain/service\.rb\z}, target: :path)

    expect(described_class.matches_pattern?('lib\\domain\\service.rb', matcher)).to be(true)
  end

  it 'selects the path-without-filename target from the filter' do
    matcher = filter(%r{\Alib/domain\z}, target: :path_without_filename)

    expect(described_class.matches_pattern?('lib/domain/service.rb', matcher)).to be(true)
  end

  it 'selects the classname target from the filter' do
    matcher = filter(/Service\z/, target: :classname)

    expect(
      described_class.matches_pattern?(
        'lib/domain/service.rb',
        matcher,
        class_name: 'OrderService'
      )
    ).to be(true)
  end

  it 'requires class information only when the filter targets a classname' do
    matcher = filter(/Service/, target: :classname)

    expect { described_class.matches_pattern?('lib/service.rb', matcher) }
      .to raise_error(ArgumentError, 'class_name is required for a classname filter')
  end

  it 'distinguishes exact and partial regular-expression matching' do
    partial = filter(/service/, target: :filename)
    exact = filter(/service/, target: :filename, matching: :exact)

    expect(described_class.matches_pattern?('order_service.rb', partial)).to be(true)
    expect(described_class.matches_pattern?('order_service.rb', exact)).to be(false)
    expect(described_class.matches_pattern?('service', exact)).to be(true)
  end

  it 'rejects a match when any exclusion filter matches' do
    exclusion = filter(/legacy/, target: :filename)
    matcher = filter(/\.rb\z/, target: :filename, exclusions: [exclusion])

    expect(described_class.matches_pattern?('lib/service.rb', matcher)).to be(true)
    expect(described_class.matches_pattern?('lib/legacy_service.rb', matcher)).to be(false)
  end

  it 'combines filters with all and any semantics' do
    ruby_file = filter(/\.rb\z/, target: :filename)
    source_path = filter(%r{\Alib/}, target: :path)
    spec_path = filter(%r{\Aspec/}, target: :path)

    expect(described_class.matches_all_patterns?('lib/service.rb', [ruby_file, source_path]))
      .to be(true)
    expect(described_class.matches_any_pattern?('lib/service.rb', [spec_path, source_path]))
      .to be(true)
    expect(described_class.matches_all_patterns?('anything', [])).to be(true)
    expect(described_class.matches_any_pattern?('anything', [])).to be(false)
  end
end
