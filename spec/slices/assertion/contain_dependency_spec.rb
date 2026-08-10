# frozen_string_literal: true

RSpec.describe ArchUnit::Slices::Assertion do
  def projected_edge(source, target)
    raw = ArchUnit::Edge.new(
      source: "lib/#{source}.rb", target: "lib/#{target}.rb", external: false
    )
    ArchUnit::ProjectedEdge.new(
      source_label: source, target_label: target, cumulated_edges: [raw]
    )
  end

  it 'returns structured evidence for the forbidden projected dependency' do
    dependency = projected_edge('api', 'database')

    expect(
      described_class.gather_forbidden_slice_dependency_violations(
        [dependency, projected_edge('api', 'services')], 'api', 'database'
      )
    ).to contain_exactly(
      ArchUnit::SliceDependencyViolation.new(
        dependency:, source_slice: 'api', target_slice: 'database',
        rule: :contain_dependency, is_negated: true
      )
    )
  end

  it 'returns no violation when the forbidden dependency is absent' do
    violations = described_class.gather_forbidden_slice_dependency_violations(
      [projected_edge('api', 'services')], 'api', 'database'
    )

    expect(violations).to eq([])
  end

  it 'validates assertion inputs and violation values' do
    dependency = projected_edge('api', 'database')

    expect do
      described_class.gather_forbidden_slice_dependency_violations([Object.new], 'api', 'database')
    end.to raise_error(ArgumentError, /ProjectedEdge/)
    expect do
      described_class.gather_forbidden_slice_dependency_violations([dependency], '', 'database')
    end.to raise_error(ArgumentError, /source_slice/)
    expect do
      ArchUnit::SliceDependencyViolation.new(
        dependency:, source_slice: 'api', target_slice: 'database',
        rule: :unknown, is_negated: true
      )
    end.to raise_error(ArgumentError, /rule/)
  end
end
