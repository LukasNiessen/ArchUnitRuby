# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Projection, '.project_edges' do
  def edge(source, target, external: false, kind: :require)
    ArchUnit::Edge.new(source:, target:, external:, import_kinds: [kind])
  end

  it 'maps edges, filters nil results, and cumulates equal label pairs' do
    first = edge('lib/api/first.rb', 'lib/domain/user.rb')
    second = edge('lib/api/second.rb', 'lib/domain/order.rb', kind: :load)
    external = edge('lib/api/first.rb', 'json', external: true)
    graph = ArchUnit::Graph.new([first, second, external])
    mapper = lambda do |raw_edge|
      next if raw_edge.external

      ArchUnit::MappedEdge.new(source_label: 'api', target_label: 'domain')
    end

    projected = described_class.project_edges(graph, mapper)

    expect(projected).to contain_exactly(
      ArchUnit::ProjectedEdge.new(
        source_label: 'api', target_label: 'domain', cumulated_edges: [first, second]
      )
    )
  end

  it 'preserves the first-seen order of projected pairs and raw evidence' do
    first = edge('a.rb', 'b.rb')
    second = edge('b.rb', 'c.rb')
    third = edge('a.rb', 'b.rb', kind: :load)
    mapper = lambda do |raw_edge|
      ArchUnit::MappedEdge.new(
        source_label: raw_edge.source, target_label: raw_edge.target
      )
    end

    projected = described_class.project_edges([first, second, third], mapper)

    expect(projected.map { |item| [item.source_label, item.target_label] }).to eq(
      [['a.rb', 'b.rb'], ['b.rb', 'c.rb']]
    )
    expect(projected.first.cumulated_edges).to eq([first, third])
  end

  it 'accepts a Ruby block as the map function hook' do
    raw_edge = edge('source.rb', 'target.rb')

    projected = described_class.project_edges([raw_edge]) do |item|
      ArchUnit::MappedEdge.new(source_label: item.source, target_label: item.target)
    end

    expect(projected.first.cumulated_edges).to eq([raw_edge])
  end

  it 'returns an immutable empty projection' do
    projected = described_class.project_edges([]) do |_edge|
      raise 'must not be called'
    end

    expect(projected).to eq([])
    expect(projected).to be_frozen
  end

  it 'rejects invalid graphs, map functions, and map results' do
    callable = ->(item) { item }

    expect { described_class.project_edges([], callable, &callable) }
      .to raise_error(ArgumentError, 'provide a mapper or a block, not both')
    expect { described_class.project_edges([], Object.new) }
      .to raise_error(ArgumentError, 'mapper must be callable')
    expect { described_class.project_edges(Object.new, ->(edge) { edge }) }
      .to raise_error(ArgumentError, 'graph must be an enumerable of Edge values')
    expect { described_class.project_edges([Object.new], ->(edge) { edge }) }
      .to raise_error(ArgumentError, 'graph must contain only Edge values')
    expect { described_class.project_edges([edge('a.rb', 'b.rb')], ->(item) { item }) }
      .to raise_error(ArgumentError, 'mapper must return a MappedEdge or nil')
  end
end
