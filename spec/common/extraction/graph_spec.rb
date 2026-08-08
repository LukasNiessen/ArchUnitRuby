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

  it 'compares by its edge list' do
    expect(described_class.new([edge])).to eq(described_class.new([edge]))
    expect(described_class.new([edge]).hash).to eq(described_class.new([edge]).hash)
  end
end
