# frozen_string_literal: true

RSpec.describe ArchUnit::GraphSnapshotFactory, '.create' do
  def edge(source, target, external: false, import_kinds: [])
    ArchUnit::Edge.new(source:, target:, external:, import_kinds:)
  end

  let(:sample_graph) do
    ArchUnit::Graph.new(
      [
        edge('src/app/controller.rb', 'src/app/controller.rb'),
        edge('src/domain/service.rb', 'src/domain/service.rb'),
        edge('src/infra/repository.rb', 'src/infra/repository.rb'),
        edge('src/orphan/alone.rb', 'src/orphan/alone.rb'),
        edge(
          'src/app/controller.rb', 'src/domain/service.rb',
          import_kinds: [:require_relative]
        ),
        edge(
          'src/app/controller.rb', 'src/domain/service.rb',
          import_kinds: [:require]
        ),
        edge(
          'src/domain/service.rb', 'src/infra/repository.rb',
          import_kinds: [:autoload]
        ),
        edge('src/app/controller.rb', 'src/infra/repository.rb'),
        edge(
          'src/app/controller.rb', 'faraday',
          external: true, import_kinds: [:require]
        )
      ]
    )
  end

  def options(**values)
    ArchUnit::GraphQueryOptions.new(**values)
  end

  it 'excludes external and self edges while preserving every internal node' do
    snapshot = described_class.create(sample_graph)

    expect(snapshot.summary).to have_attributes(
      node_count: 4, edge_count: 3, raw_edge_count: 4, external_edge_count: 0
    )
    expect(snapshot.nodes.map(&:label)).to eq(
      %w[
        src/app/controller.rb src/domain/service.rb
        src/infra/repository.rb src/orphan/alone.rb
      ]
    )
    expect(snapshot.edges).to include(
      have_attributes(
        source: 'src/app/controller.rb', target: 'src/domain/service.rb',
        count: 2, external: false, import_kinds: %i[require require_relative]
      )
    )
  end

  it 'can include external dependencies and source self-edges' do
    snapshot = described_class.create(
      sample_graph,
      options(include_external_dependencies: true, include_self_dependencies: true)
    )

    expect(snapshot.summary).to have_attributes(
      node_count: 5, edge_count: 8, raw_edge_count: 9, external_edge_count: 1
    )
    expect(snapshot.nodes.map(&:label)).to include('faraday')
    expect(snapshot.edges).to include(
      have_attributes(
        source: 'src/app/controller.rb', target: 'faraday', count: 1, external: true
      ),
      have_attributes(
        source: 'src/orphan/alone.rb', target: 'src/orphan/alone.rb', count: 1
      )
    )
  end

  it 'focuses on matching nodes and expands undirected neighbors to the requested depth' do
    filter = ArchUnit::RegexFactory.path_matcher('src/domain/**')
    exact = described_class.create(sample_graph, options(focus: filter, focus_depth: 0))
    neighbors = described_class.create(sample_graph, options(focus: filter, focus_depth: 1))

    expect(exact.nodes.map(&:label)).to eq(['src/domain/service.rb'])
    expect(exact.edges).to be_empty
    expect(neighbors.nodes.map(&:label)).to eq(
      %w[src/app/controller.rb src/domain/service.rb src/infra/repository.rb]
    )
    expect(neighbors.summary.edge_count).to eq(3)
  end

  it 'selects transitive dependencies and reverse dependents' do
    domain = ArchUnit::RegexFactory.path_matcher('src/domain/**')
    infra = ArchUnit::RegexFactory.path_matcher('src/infra/**')
    reachable = described_class.create(sample_graph, options(reachable_from: domain))
    dependents = described_class.create(sample_graph, options(dependents_of: infra))

    expect(reachable.nodes.map(&:label)).to eq(
      %w[src/domain/service.rb src/infra/repository.rb]
    )
    expect(reachable.summary.edge_count).to eq(1)
    expect(dependents.nodes.map(&:label)).to eq(
      %w[src/app/controller.rb src/domain/service.rb src/infra/repository.rb]
    )
    expect(dependents.summary.edge_count).to eq(3)
  end

  it 'combines several query modifiers as a union' do
    orphan = ArchUnit::RegexFactory.path_matcher('src/orphan/**')
    domain = ArchUnit::RegexFactory.path_matcher('src/domain/**')
    snapshot = described_class.create(
      sample_graph, options(focus: orphan, focus_depth: 0, reachable_from: domain)
    )

    expect(snapshot.nodes.map(&:label)).to eq(
      %w[src/domain/service.rb src/infra/repository.rb src/orphan/alone.rb]
    )
  end

  it 'collapses nodes to folder depth before aggregating edges' do
    snapshot = described_class.create(
      sample_graph, options(collapse: ArchUnit::FolderDepthCollapse.new(depth: 2))
    )

    expect(snapshot.nodes.map(&:label)).to eq(
      %w[src/app src/domain src/infra src/orphan]
    )
    expect(snapshot.edges).to include(
      have_attributes(source: 'src/app', target: 'src/domain', count: 2)
    )
  end

  it 'collapses by regular-expression replacement and removes collapsed self-edges' do
    collapse = ArchUnit::PatternCollapse.from('src/([^/]+)/.*', '\\1')
    graph = ArchUnit::Graph.new(
      [
        *sample_graph.to_a,
        edge('src/app/controller.rb', 'src/app/helper.rb', import_kinds: [:load])
      ]
    )
    snapshot = described_class.create(graph, options(collapse:))

    expect(snapshot.nodes.map(&:label)).to eq(%w[app domain infra orphan])
    expect(snapshot.edges).not_to include(have_attributes(source: 'app', target: 'app'))
    expect(snapshot.edges).to include(have_attributes(source: 'app', target: 'domain', count: 2))
  end

  it 'returns deeply immutable snapshot values with stable identifiers and title' do
    snapshot = described_class.create(sample_graph, options(title: 'Application Architecture'))

    expect(snapshot).to be_frozen
    expect(snapshot.nodes).to be_frozen
    expect(snapshot.edges).to be_frozen
    expect(snapshot.title).to eq('Application Architecture')
    expect(snapshot.nodes.map(&:id)).to eq(%w[n0 n1 n2 n3])
    expect(snapshot.nodes).to all(be_frozen)
    expect(snapshot.edges).to all(be_frozen)
    expect(snapshot.summary).to be_frozen
  end

  it 'validates query, collapse, snapshot, and summary values defensively' do
    expect { described_class.create(Object.new) }.to raise_error(ArgumentError, /Graph/)
    expect { ArchUnit::GraphQueryOptions.new(include_external_dependencies: nil) }
      .to raise_error(ArgumentError, /true or false/)
    expect { ArchUnit::GraphQueryOptions.new(focus: Object.new) }
      .to raise_error(ArgumentError, /Filter/)
    expect { ArchUnit::GraphQueryOptions.new(focus_depth: -1) }
      .to raise_error(ArgumentError, /non-negative/)
    expect { ArchUnit::GraphQueryOptions.new(collapse: Object.new) }
      .to raise_error(ArgumentError, /collapse/)
    expect { ArchUnit::GraphQueryOptions.new(title: '') }
      .to raise_error(ArgumentError, /title/)
    expect { ArchUnit::FolderDepthCollapse.new(depth: 0) }
      .to raise_error(ArgumentError, /positive/)
    expect { ArchUnit::PatternCollapse.from('[') }
      .to raise_error(ArgumentError, /invalid collapse pattern/)
    expect do
      ArchUnit::GraphReportSummary.new(
        node_count: -1, edge_count: 0, raw_edge_count: 0, external_edge_count: 0
      )
    end.to raise_error(ArgumentError, /node_count/)
  end
end
