# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Projection, '.project_to_nodes' do
  def edge(source, target, external: false)
    ArchUnit::Edge.new(source:, target:, external:)
  end

  it 'uses self-edges to retain isolated nodes without reporting self-dependencies' do
    isolated = edge('isolated.rb', 'isolated.rb')

    nodes = described_class.project_to_nodes([isolated])

    expect(nodes).to contain_exactly(
      ArchUnit::ProjectedNode.new(label: 'isolated.rb')
    )
  end

  it 'groups internal edges into sorted nodes with incoming and outgoing evidence' do
    dependency = edge('a.rb', 'b.rb')
    graph = [edge('b.rb', 'b.rb'), dependency, edge('a.rb', 'a.rb')]

    nodes = described_class.project_to_nodes(graph)

    expect(nodes.map(&:label)).to eq(%w[a.rb b.rb])
    expect(nodes.first).to have_attributes(incoming: [], outgoing: [dependency])
    expect(nodes.last).to have_attributes(incoming: [dependency], outgoing: [])
  end

  it 'omits external target nodes by default but keeps the source outgoing edge' do
    dependency = edge('source.rb', 'json', external: true)

    nodes = described_class.project_to_nodes([dependency])

    expect(nodes.map(&:label)).to eq(['source.rb'])
    expect(nodes.first.outgoing).to eq([dependency])
  end

  it 'includes external target nodes when requested' do
    dependency = edge('source.rb', 'json', external: true)

    nodes = described_class.project_to_nodes([dependency], include_externals: true)

    expect(nodes.map(&:label)).to eq(%w[json source.rb])
    expect(nodes.first.incoming).to eq([dependency])
    expect(nodes.last.outgoing).to eq([dependency])
  end

  it 'returns an immutable node collection and immutable node values' do
    nodes = described_class.project_to_nodes([edge('source.rb', 'source.rb')])

    expect(nodes).to be_frozen
    expect(nodes).to all(be_frozen)
  end

  it 'rejects invalid graph values and options' do
    expect { described_class.project_to_nodes(Object.new) }
      .to raise_error(ArgumentError, 'graph must be an enumerable of Edge values')
    expect { described_class.project_to_nodes([Object.new]) }
      .to raise_error(ArgumentError, 'graph must contain only Edge values')
    expect { described_class.project_to_nodes([], include_externals: nil) }
      .to raise_error(ArgumentError, 'include_externals must be true or false')
  end
end
