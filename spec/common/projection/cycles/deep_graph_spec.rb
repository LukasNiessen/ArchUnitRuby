# frozen_string_literal: true

RSpec.describe 'Cycle analysis on deep graphs' do
  let(:size) { 10_000 }
  let(:vertices) { (0...size).to_a }
  let(:chain) { vertices.to_h { |vertex| [vertex, vertex + 1 < size ? [vertex + 1] : []] } }
  let(:algorithms) { ArchUnit::Common::Projection::Cycles }

  it 'finds every component of a long acyclic chain without growing the Ruby call stack' do
    expect(algorithms::TarjanScc.call(chain)).to match_array(vertices.map { |vertex| [vertex] })
  end

  it 'returns no cycles for a long acyclic chain' do
    expect(algorithms::JohnsonCycles.call(chain)).to eq([])
  end

  it 'enumerates a long ring once, preserving its directed order' do
    ring = vertices.to_h { |vertex| [vertex, [(vertex + 1) % size]] }
    expect(algorithms::JohnsonCycles.call(ring)).to eq([vertices])
  end

  it 'unblocks a deep dependency chain without recursion' do
    search = algorithms::JohnsonCycles.new(chain)
    blocked_by = vertices.to_h { |vertex| [vertex, Set.new(chain.fetch(vertex))] }
    search.instance_variable_set(:@blocked, vertices.to_set)
    search.instance_variable_set(:@blocked_by, blocked_by)

    search.__send__(:unblock, 0)

    expect(search.instance_variable_get(:@blocked)).to be_empty
    expect(search.instance_variable_get(:@blocked_by)).to be_empty
  end
end
