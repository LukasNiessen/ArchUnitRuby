# frozen_string_literal: true

RSpec.describe 'projection values' do
  let(:edge) do
    ArchUnit::Edge.new(
      source: 'lib/source.rb', target: 'lib/target.rb', external: false,
      import_kinds: [:require]
    )
  end

  it 'stores immutable mapped labels' do
    source = +'source'
    mapped = ArchUnit::MappedEdge.new(source_label: source, target_label: 'target')
    source.replace('changed')

    expect(mapped).to have_attributes(source_label: 'source', target_label: 'target')
    expect(mapped).to be_frozen
    expect(mapped.source_label).to be_frozen
    expect(mapped.target_label).to be_frozen
  end

  it 'stores immutable projected edges with their raw evidence' do
    raw_edges = [edge]
    projected = ArchUnit::ProjectedEdge.new(
      source_label: 'source', target_label: 'target', cumulated_edges: raw_edges
    )
    raw_edges.clear

    expect(projected.cumulated_edges).to eq([edge])
    expect(projected).to be_frozen
    expect(projected.cumulated_edges).to be_frozen
  end

  it 'stores immutable projected nodes with incoming and outgoing evidence' do
    incoming = [edge]
    outgoing = [edge]
    node = ArchUnit::ProjectedNode.new(label: 'target', incoming:, outgoing:)
    incoming.clear
    outgoing.clear

    expect(node).to have_attributes(label: 'target', incoming: [edge], outgoing: [edge])
    expect(node).to be_frozen
    expect(node.incoming).to be_frozen
    expect(node.outgoing).to be_frozen
  end

  it 'rejects invalid labels and raw-edge collections' do
    expect { ArchUnit::MappedEdge.new(source_label: '', target_label: 'target') }
      .to raise_error(ArgumentError, /source_label/)
    expect do
      ArchUnit::ProjectedEdge.new(
        source_label: 'source', target_label: 'target', cumulated_edges: []
      )
    end.to raise_error(ArgumentError, /at least one Edge/)
    expect { ArchUnit::ProjectedNode.new(label: 'node', incoming: [Object.new]) }
      .to raise_error(ArgumentError, /incoming/)
  end
end
