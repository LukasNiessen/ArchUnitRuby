# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Projection::Cycles::JohnsonCycles do
  it 'returns no cycles for an acyclic graph' do
    expect(described_class.call(0 => [1], 1 => [2], 2 => [])).to eq([])
  end

  it 'finds disconnected and overlapping elementary cycles exactly once' do
    adjacency = {
      0 => [1, 2], 1 => [0, 2], 2 => [0, 1],
      3 => [4], 4 => [3]
    }

    cycles = described_class.call(adjacency)

    expect(cycles).to contain_exactly(
      [0, 1], [0, 2], [1, 2], [0, 1, 2], [0, 2, 1], [3, 4]
    )
    expect(cycles.uniq.length).to eq(cycles.length)
  end

  it 'filters self-edges before enumeration' do
    expect(described_class.call(0 => [0], 1 => [1])).to eq([])
  end

  it 'enumerates every elementary cycle in a dense four-node graph' do
    adjacency = (0..3).to_h do |vertex|
      [vertex, (0..3).reject { |neighbour| neighbour == vertex }]
    end

    cycles = described_class.call(adjacency)

    expect(cycles.length).to eq(20)
    expect(cycles.uniq.length).to eq(20)
    expect(cycles).to all(satisfy { |cycle| cycle.uniq.length == cycle.length })
  end

  it 'matches exhaustive enumeration across deterministic small random graphs' do
    random = Random.new(15)

    50.times do
      adjacency = (0..4).to_h do |source|
        targets = (0..4).reject do |target|
          source == target || random.rand >= 0.35
        end
        [source, targets]
      end

      expect(described_class.call(adjacency).to_set).to eq(exhaustive_cycles(adjacency))
    end
  end

  def exhaustive_cycles(adjacency)
    vertices = adjacency.keys
    (2..vertices.length).each_with_object(Set.new) do |length, cycles|
      append_cycles(cycles, vertices.permutation(length), adjacency)
    end
  end

  def append_cycles(cycles, candidates, adjacency)
    candidates.each do |path|
      next unless path.first == path.min && connected_cycle?(path, adjacency)

      cycles.add(path)
    end
  end

  def connected_cycle?(path, adjacency)
    path.each_index.all? do |index|
      adjacency.fetch(path.fetch(index)).include?(path.fetch((index + 1) % path.length))
    end
  end
end
