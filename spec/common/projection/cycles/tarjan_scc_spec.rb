# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Projection::Cycles::TarjanScc do
  it 'separates strongly connected components from acyclic vertices' do
    adjacency = {
      0 => [1], 1 => [2], 2 => [0, 3],
      3 => [4], 4 => [3], 5 => []
    }

    components = described_class.call(adjacency)

    expect(components).to contain_exactly([0, 1, 2], [3, 4], [5])
  end

  it 'honors the requested induced subgraph' do
    adjacency = { 0 => [1], 1 => [0, 2], 2 => [3], 3 => [2] }

    components = described_class.call(adjacency, vertices: [1, 2, 3])

    expect(components).to contain_exactly([1], [2, 3])
  end

  it 'returns immutable components for an empty graph' do
    components = described_class.call({})

    expect(components).to eq([])
    expect(components).to be_frozen
  end
end
