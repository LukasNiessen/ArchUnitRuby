# frozen_string_literal: true

RSpec.describe ArchUnit::Testing::ViolationFactory do
  def projected_edge(source, target, external: false)
    raw = ArchUnit::Edge.new(source:, target:, external:)
    ArchUnit::ProjectedEdge.new(
      source_label: source, target_label: target, cumulated_edges: [raw]
    )
  end

  def file_info(path)
    ArchUnit::FileInfo.new(
      path:, name: File.basename(path, '.rb'), extension: '.rb',
      directory: File.dirname(path), content: '# fixture', lines_of_code: 1
    )
  end

  it 'formats empty selections and their selector data' do
    filter = ArchUnit::RegexFactory.folder_matcher('lib/services')
    formatted = described_class.from_violation(
      ArchUnit::EmptyTestViolation.new(filters: [filter], is_negated: true)
    )

    expect(formatted.message).to eq('No files matched the rule scope')
    expect(formatted.details).to include('folder pattern', 'lib/services')
  end

  it 'formats positive and negated file pattern violations' do
    filter = ArchUnit::RegexFactory.filename_matcher('*_service.rb')
    node = ArchUnit::ProjectedNode.new(label: 'lib/order.rb')
    positive = ArchUnit::FilePatternViolation.new(
      check_filter: filter, projected_node: node
    )
    negative = ArchUnit::FilePatternViolation.new(
      check_filter: filter, projected_node: node, is_negated: true
    )

    expect(described_class.from_violation(positive).details).to include('does not match required')
    expect(described_class.from_violation(negative).details).to include('matches forbidden')
  end

  it 'formats internal and external dependency evidence in both moods' do
    internal = projected_edge('lib/api.rb', 'lib/database.rb')
    external = projected_edge('lib/api.rb', 'faraday', external: true)
    internal_violation = ArchUnit::FileDependencyViolation.new(
      dependency: internal, is_negated: true
    )
    external_violation = ArchUnit::ExternalModuleDependencyViolation.new(
      dependency: external
    )

    expect(described_class.from_violation(internal_violation).details).to eq(
      "File 'lib/api.rb' depends on forbidden file 'lib/database.rb'."
    )
    expect(described_class.from_violation(external_violation).details).to eq(
      "File 'lib/api.rb' depends on external module outside the allowlist 'faraday'."
    )
  end

  it 'formats cycle paths as closed readable evidence' do
    first = projected_edge('lib/a.rb', 'lib/b.rb')
    second = projected_edge('lib/b.rb', 'lib/a.rb')
    violation = ArchUnit::CycleViolation.new(cycle: [first, second])

    expect(described_class.from_violation(violation)).to have_attributes(
      message: 'Circular dependency detected',
      details: 'Cycle: lib/a.rb -> lib/b.rb -> lib/a.rb.'
    )
  end

  it 'keeps the user message and FileInfo evidence for custom violations' do
    violation = ArchUnit::CustomFileViolation.new(
      file_info: file_info('lib/legacy.rb'), message: 'legacy source forbidden',
      is_negated: true
    )

    expect(described_class.from_violation(violation)).to have_attributes(
      message: 'legacy source forbidden',
      details: "File 'lib/legacy.rb' matched the forbidden predicate."
    )
  end

  it 'formats layer allowlist and blocklist violations with edge evidence' do
    edge = projected_edge('app/api/orders.rb', 'app/database/orders.rb')
    allowlist = ArchUnit::LayerDependencyViolation.new(
      dependency: edge, source_layer: 'api', target_layer: 'database',
      rule: :may_only_depend_on_layers
    )
    blocklist = ArchUnit::LayerDependencyViolation.new(
      dependency: edge, source_layer: 'api', target_layer: 'database',
      rule: :may_not_depend_on_layers
    )

    expect(described_class.from_violation(allowlist)).to have_attributes(
      message: 'Layer dependency violation',
      details: "Layer 'api' depends on layer outside its allowlist 'database' via " \
               "'app/api/orders.rb' -> 'app/database/orders.rb'."
    )
    expect(described_class.from_violation(blocklist).details)
      .to include("Layer 'api' depends on forbidden layer 'database'")
  end

  it 'formats unknown future violations without leaking object identities' do
    formatted = described_class.from_violation(ArchUnit::Violation.new)

    expect(formatted.message).to eq('Architecture violation')
    expect(formatted.details).to eq(
      'Unformatted violation type: ArchUnit::Common::Assertion::Violation.'
    )
  end

  it 'returns immutable validated presentation values' do
    formatted = described_class.from_violation(ArchUnit::EmptyTestViolation.new(filters: []))

    expect(formatted).to be_frozen
    expect(formatted.message).to be_frozen
    expect { ArchUnit::TestViolation.new(message: '', details: 'details') }
      .to raise_error(ArgumentError, /message/)
    expect { described_class.from_violation(Object.new) }
      .to raise_error(ArgumentError, /Violation/)
  end
end
