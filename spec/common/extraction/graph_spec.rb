# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Extraction::Graph do
  let(:edge) do
    ArchUnit::Common::Extraction::Edge.new(
      source: 'lib/source.rb',
      target: 'lib/target.rb',
      external: false,
      import_kinds: [:require]
    )
  end

  it 'behaves as an immutable enumerable list of edges' do
    graph = described_class.new([edge])

    expect(graph).to be_frozen
    expect(graph.edges).to be_frozen
    expect(graph.size).to eq(1)
    expect(graph.map(&:target)).to eq(['lib/target.rb'])
    expect(graph.first).to equal(edge)
    expect(graph[0]).to equal(edge)
  end

  it "does not share the caller's mutable array" do
    input = [edge]
    graph = described_class.new(input)

    input.clear

    expect(graph.to_a).to eq([edge])
  end

  it 'rejects values that are not edges' do
    expect { described_class.new([Object.new]) }
      .to raise_error(ArgumentError, 'graph accepts only Edge values')
  end

  it 'accepts consistently project-relative identifiers' do
    expect(described_class.new([edge])).to contain_exactly(edge)
  end

  it 'accepts consistently absolute identifiers' do
    absolute_edge = ArchUnit::Common::Extraction::Edge.new(
      source: '/project/lib/source.rb',
      target: '/project/lib/target.rb',
      external: false
    )

    expect(described_class.new([absolute_edge])).to contain_exactly(absolute_edge)
  end

  it 'rejects mixed absolute and project-relative internal identifiers' do
    mixed_edge = ArchUnit::Common::Extraction::Edge.new(
      source: 'C:\\project\\lib\\source.rb',
      target: 'lib/target.rb',
      external: false
    )

    expect { described_class.new([mixed_edge]) }
      .to raise_error(
        ArgumentError,
        'graph identifiers must be either all absolute or all project-relative'
      )
  end

  it 'does not treat an external target as a project path' do
    external_edge = ArchUnit::Common::Extraction::Edge.new(
      source: '/project/lib/source.rb',
      target: 'bundler/setup',
      external: true,
      import_kinds: [:require]
    )

    expect(described_class.new([external_edge])).to contain_exactly(external_edge)
  end

  it 'compares by its edge list' do
    expect(described_class.new([edge])).to eq(described_class.new([edge]))
    expect(described_class.new([edge]).hash).to eq(described_class.new([edge]).hash)
  end
end
