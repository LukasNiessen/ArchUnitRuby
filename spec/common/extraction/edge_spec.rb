# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Extraction::Edge do
  subject(:edge) do
    described_class.new(
      source: 'lib/source.rb',
      target: 'lib/target.rb',
      external: false,
      import_kinds: %i[require require_relative require]
    )
  end

  it 'carries immutable dependency data' do
    expect(edge).to have_attributes(
      source: 'lib/source.rb',
      target: 'lib/target.rb',
      external: false,
      import_kinds: %i[require require_relative]
    )
    expect(edge).to be_frozen
    expect(edge.source).to be_frozen
    expect(edge.target).to be_frozen
    expect(edge.import_kinds).to be_frozen
  end

  it 'protects itself from mutations to constructor values' do
    source = +'lib/source.rb'
    kinds = [:require]
    value = described_class.new(
      source:,
      target: 'lib/target.rb',
      external: false,
      import_kinds: kinds
    )

    source << '.changed'
    kinds << :load

    expect(value.source).to eq('lib/source.rb')
    expect(value.import_kinds).to eq([:require])
  end

  it 'normalizes identifier separators' do
    value = described_class.new(
      source: 'lib\\source.rb',
      target: 'lib\\nested/target.rb',
      external: false
    )

    expect(value.source).to eq('lib/source.rb')
    expect(value.target).to eq('lib/nested/target.rb')
  end

  it 'uses no import kinds for a self-edge by default' do
    value = described_class.new(source: 'lib/a.rb', target: 'lib/a.rb', external: false)

    expect(value.import_kinds).to be_empty
    expect(value.import_kinds).to be_frozen
  end

  it 'rejects unknown import kinds' do
    expect do
      described_class.new(
        source: 'lib/a.rb',
        target: 'lib/b.rb',
        external: false,
        import_kinds: [:dynamic]
      )
    end.to raise_error(ArgumentError, 'unknown import kinds: :dynamic')
  end

  it 'requires non-empty identifiers and a boolean external flag' do
    expect do
      described_class.new(source: '', target: 'lib/b.rb', external: false)
    end.to raise_error(ArgumentError, 'source must be a non-empty String')

    expect do
      described_class.new(source: 'lib/a.rb', target: 'lib/b.rb', external: nil)
    end.to raise_error(ArgumentError, 'external must be true or false')
  end
end
