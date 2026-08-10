# frozen_string_literal: true

RSpec.describe ArchUnit::Files::Assertion, '.gather_file_dependency_violations' do
  def projected_edge(source, target)
    raw_edge = ArchUnit::Edge.new(source:, target:, external: false)
    ArchUnit::ProjectedEdge.new(
      source_label: source, target_label: target, cumulated_edges: [raw_edge]
    )
  end

  let(:subjects) { [ArchUnit::RegexFactory.folder_matcher('lib/controllers')] }
  let(:objects) { [ArchUnit::RegexFactory.folder_matcher('lib/services')] }

  it 'treats a positive rule as an allowlist for matching subjects' do
    allowed = projected_edge('lib/controllers/orders.rb', 'lib/services/orders.rb')
    disallowed = projected_edge('lib/controllers/orders.rb', 'lib/database/orders.rb')

    violations = described_class.gather_file_dependency_violations(
      [allowed, disallowed], subjects, objects, is_negated: false
    )

    expect(violations).to contain_exactly(
      ArchUnit::FileDependencyViolation.new(dependency: disallowed)
    )
  end

  it 'reports matching forbidden dependencies in the negated mood' do
    forbidden = projected_edge('lib/controllers/orders.rb', 'lib/services/orders.rb')
    permitted = projected_edge('lib/controllers/orders.rb', 'lib/database/orders.rb')

    violations = described_class.gather_file_dependency_violations(
      [forbidden, permitted], subjects, objects, is_negated: true
    )

    expect(violations).to contain_exactly(
      ArchUnit::FileDependencyViolation.new(dependency: forbidden, is_negated: true)
    )
    expect(violations.first).to be_negated
  end

  it 'combines every subject and object selector with AND semantics' do
    subject_filters = [
      *subjects, ArchUnit::RegexFactory.filename_matcher('*_controller.rb')
    ]
    object_filters = [
      *objects, ArchUnit::RegexFactory.filename_matcher('*_service.rb')
    ]
    matching = projected_edge(
      'lib/controllers/order_controller.rb', 'lib/services/order_service.rb'
    )
    wrong_subject = projected_edge('lib/controllers/order.rb', 'lib/services/order_service.rb')
    wrong_object = projected_edge(
      'lib/controllers/order_controller.rb', 'lib/services/order_repository.rb'
    )

    violations = described_class.gather_file_dependency_violations(
      [matching, wrong_subject, wrong_object], subject_filters, object_filters,
      is_negated: true
    )

    expect(violations.map(&:dependency)).to eq([matching])
  end

  it 'creates immutable value-comparable violation data' do
    dependency = projected_edge('lib/a.rb', 'lib/b.rb')
    violation = ArchUnit::FileDependencyViolation.new(dependency:, is_negated: true)
    equal_value = ArchUnit::FileDependencyViolation.new(dependency:, is_negated: true)

    expect(violation).to eq(equal_value)
    expect(violation.hash).to eq(equal_value.hash)
    expect(violation).to be_frozen
  end

  it 'rejects invalid edges, filters, empty objects, and mood flags' do
    expect do
      described_class.gather_file_dependency_violations(
        [Object.new], subjects, objects, is_negated: false
      )
    end.to raise_error(ArgumentError, /ProjectedEdge/)
    expect do
      described_class.gather_file_dependency_violations(
        [], [Object.new], objects, is_negated: false
      )
    end.to raise_error(ArgumentError, /subject_filters/)
    expect do
      described_class.gather_file_dependency_violations([], subjects, [], is_negated: false)
    end.to raise_error(ArgumentError, /non-empty/)
    expect do
      described_class.gather_file_dependency_violations([], subjects, objects, is_negated: nil)
    end.to raise_error(ArgumentError, /true or false/)
  end
end
