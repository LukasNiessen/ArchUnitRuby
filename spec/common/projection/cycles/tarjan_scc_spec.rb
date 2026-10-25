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

  it 'matches mutual reachability on deterministic random induced subgraphs' do
    random = Random.new(640)
    100.times do
      adjacency = (0..7).to_h do |vertex|
        [vertex, (0..7).select { random.rand < 0.25 }]
      end
      allowed = (0..7).select { random.rand < 0.8 }.to_set
      reachable = allowed.to_h { |vertex| [vertex, reachable_from(adjacency, vertex, allowed)] }
      expected = allowed.group_by do |vertex|
        reachable.fetch(vertex).select { |other| reachable.fetch(other).include?(vertex) }.sort
      end.values.map(&:sort)

      expect(described_class.call(adjacency, vertices: allowed)).to match_array(expected)
    end
  end

  def reachable_from(adjacency, start, allowed)
    pending = [start]
    visited = Set.new
    until pending.empty?
      vertex = pending.pop
      next unless allowed.include?(vertex) && visited.add?(vertex)

      pending.concat(adjacency.fetch(vertex))
    end
    visited
  end
end
