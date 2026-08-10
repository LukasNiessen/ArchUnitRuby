# frozen_string_literal: true

RSpec.describe ArchUnit::Slices::Assertion do
  def projected_edge(source, target, external: false)
    raw = ArchUnit::Edge.new(
      source: "lib/#{source}.rb", target: external ? target : "lib/#{target}.rb", external:
    )
    ArchUnit::ProjectedEdge.new(
      source_label: source, target_label: target, cumulated_edges: [raw]
    )
  end

  let(:diagram) do
    ArchUnit::PlantUmlDiagram.new(
      components: %w[api services database],
      dependencies: [ArchUnit::PlantUmlDependency.new(source: 'api', target: 'services')]
    )
  end

  let(:edges) do
    [
      projected_edge('api', 'services'),
      projected_edge('api', 'database'),
      projected_edge('api', 'json', external: true)
    ]
  end

  it 'returns evidence for every actual dependency the diagram does not allow' do
    violations = described_class.gather_diagram_adherence_violations(edges, diagram)

    expect(violations.map { |item| [item.source_slice, item.target_slice] }).to contain_exactly(
      %w[api database], %w[api json]
    )
    expect(violations).to all(
      be_a(ArchUnit::SliceDependencyViolation).and(
        have_attributes(rule: :adhere_to_diagram, negated?: false)
      )
    )
  end

  it 'can ignore external dependencies without hiding internal violations' do
    options = ArchUnit::DiagramAdherenceOptions.new(ignore_external_slices: true)
    violations = described_class.gather_diagram_adherence_violations(edges, diagram, options)

    expect(violations).to contain_exactly(have_attributes(target_slice: 'database'))
  end

  it 'can ignore dependencies with endpoints not declared by the diagram' do
    narrow_diagram = ArchUnit::PlantUmlDiagram.new(
      components: %w[api services],
      dependencies: [ArchUnit::PlantUmlDependency.new(source: 'api', target: 'services')]
    )
    options = ArchUnit::DiagramAdherenceOptions.new(ignore_orphan_slices: true)

    expect(
      described_class.gather_diagram_adherence_violations(edges, narrow_diagram, options)
    ).to eq([])
  end

  it 'keeps immutable modifiers independent and validates assertion options' do
    base = ArchUnit::DiagramAdherenceOptions.new
    external = base.with(ignore_external_slices: true)

    expect(base.ignore_external_slices?).to be(false)
    expect(external.ignore_external_slices?).to be(true)
    expect([base, external]).to all(be_frozen)
    expect do
      described_class.gather_diagram_adherence_violations(edges, Object.new)
    end.to raise_error(ArgumentError, /PlantUmlDiagram/)
    expect do
      ArchUnit::DiagramAdherenceOptions.new(ignore_orphan_slices: :yes)
    end.to raise_error(ArgumentError, /true or false/)
  end
end
