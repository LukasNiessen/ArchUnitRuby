# frozen_string_literal: true

RSpec.describe ArchUnit::Layers::Assertion, '.gather_layer_dependency_violations' do
  def projected_edge(source, target)
    raw_edge = ArchUnit::Edge.new(source:, target:, external: false)
    ArchUnit::ProjectedEdge.new(
      source_label: source, target_label: target, cumulated_edges: [raw_edge]
    )
  end

  def layer(name, folder)
    ArchUnit::LayerDefinition.new(
      name:, filters: [ArchUnit::RegexFactory.folder_matcher(folder)]
    )
  end

  let(:layers) do
    [
      layer('controllers', 'app/controllers'),
      layer('services', 'app/services'),
      layer('models', 'app/models')
    ]
  end

  it 'reports only cross-layer edges outside a source allowlist' do
    allowed = projected_edge('app/controllers/orders.rb', 'app/services/orders.rb')
    rejected = projected_edge('app/controllers/orders.rb', 'app/models/order.rb')
    intra_layer = projected_edge('app/controllers/orders.rb', 'app/controllers/base.rb')

    violations = described_class.gather_layer_dependency_violations(
      [allowed, rejected, intra_layer], layers, { 'controllers' => ['services'] }, {}
    )

    expect(violations).to contain_exactly(
      ArchUnit::LayerDependencyViolation.new(
        dependency: rejected, source_layer: 'controllers', target_layer: 'models',
        rule: :may_only_depend_on_layers
      )
    )
  end

  it 'treats an empty allowlist as a sealed layer' do
    edge = projected_edge('app/controllers/orders.rb', 'app/services/orders.rb')

    violations = described_class.gather_layer_dependency_violations(
      [edge], layers, { 'controllers' => [] }, {}
    )

    expect(violations.one?).to be(true)
    expect(violations.first).to have_attributes(
      source_layer: 'controllers', target_layer: 'services',
      rule: :may_only_depend_on_layers
    )
  end

  it 'evaluates blocklists before allowlists and emits one violation per edge' do
    edge = projected_edge('app/controllers/orders.rb', 'app/services/orders.rb')

    violations = described_class.gather_layer_dependency_violations(
      [edge], layers,
      { 'controllers' => ['models'] },
      { 'controllers' => ['services'] }
    )

    expect(violations.one?).to be(true)
    expect(violations.first.rule).to eq(:may_not_depend_on_layers)
  end

  it 'ignores edges with either endpoint outside every declared layer' do
    from_unassigned = projected_edge('app/jobs/sync.rb', 'app/models/order.rb')
    to_unassigned = projected_edge('app/services/orders.rb', 'app/support/logger.rb')

    violations = described_class.gather_layer_dependency_violations(
      [from_unassigned, to_unassigned], layers,
      { 'services' => [] }, { 'models' => ['services'] }
    )

    expect(violations).to be_empty
  end

  it 'uses the first declared layer deterministically when definitions overlap' do
    broad = layer('application', 'app/**')
    specific = layer('services', 'app/services')
    edge = projected_edge('app/services/orders.rb', 'app/models/order.rb')

    violations = described_class.gather_layer_dependency_violations(
      [edge], [broad, specific, *layers], { 'application' => [] }, {}
    )

    expect(violations).to be_empty
  end

  it 'returns immutable value-comparable definitions and violations' do
    definition = layer('services', 'app/services')
    equal_definition = layer('services', 'app/services')
    dependency = projected_edge('app/services/orders.rb', 'app/models/order.rb')
    violation = ArchUnit::LayerDependencyViolation.new(
      dependency:, source_layer: 'services', target_layer: 'models',
      rule: :may_not_depend_on_layers
    )

    expect(definition).to eq(equal_definition)
    expect(definition.hash).to eq(equal_definition.hash)
    expect(definition).to be_frozen
    expect(violation).to be_frozen
  end

  it 'rejects malformed pure assertion inputs and violation values' do
    expect do
      described_class.gather_layer_dependency_violations([Object.new], layers, {}, {})
    end.to raise_error(ArgumentError, /ProjectedEdge/)
    expect do
      described_class.gather_layer_dependency_violations([], [Object.new], {}, {})
    end.to raise_error(ArgumentError, /LayerDefinition/)
    expect do
      described_class.gather_layer_dependency_violations([], layers, { nil => [] }, {})
    end.to raise_error(ArgumentError, /allowed_dependencies/)
    expect do
      ArchUnit::LayerDependencyViolation.new(
        dependency: Object.new, source_layer: 'a', target_layer: 'b',
        rule: :may_only_depend_on_layers
      )
    end.to raise_error(ArgumentError, /ProjectedEdge/)
  end
end
