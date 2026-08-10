# frozen_string_literal: true

RSpec.describe ArchUnit::Files::Assertion, '.gather_external_module_dependency_violations' do
  def projected_edge(source, target)
    raw_edge = ArchUnit::Edge.new(source:, target:, external: true)
    ArchUnit::ProjectedEdge.new(
      source_label: source, target_label: target, cumulated_edges: [raw_edge]
    )
  end

  let(:subjects) { [ArchUnit::RegexFactory.folder_matcher('lib/clients')] }
  let(:modules) { [ArchUnit::RegexFactory.path_matcher('json')] }

  it 'reports matching forbidden modules in the negated mood' do
    forbidden = projected_edge('lib/clients/api_client.rb', 'json')
    permitted = projected_edge('lib/clients/api_client.rb', 'net/http')

    violations = described_class.gather_external_module_dependency_violations(
      [forbidden, permitted], subjects, modules, is_negated: true
    )

    expect(violations).to contain_exactly(
      ArchUnit::ExternalModuleDependencyViolation.new(
        dependency: forbidden, is_negated: true
      )
    )
  end

  it 'treats a positive rule as an external-module allowlist' do
    allowed = projected_edge('lib/clients/api_client.rb', 'json')
    disallowed = projected_edge('lib/clients/api_client.rb', 'net/http')

    violations = described_class.gather_external_module_dependency_violations(
      [allowed, disallowed], subjects, modules, is_negated: false
    )

    expect(violations.map(&:dependency)).to eq([disallowed])
  end

  it 'combines repeated module selectors with OR semantics' do
    module_filters = [
      *modules, ArchUnit::RegexFactory.path_matcher('net/**')
    ]
    json = projected_edge('lib/clients/api_client.rb', 'json')
    http = projected_edge('lib/clients/api_client.rb', 'net/http')

    violations = described_class.gather_external_module_dependency_violations(
      [json, http], subjects, module_filters, is_negated: true
    )

    expect(violations.map(&:dependency)).to contain_exactly(json, http)
  end

  it 'ANDs subject selectors and ignores external edges from other files' do
    subject_filters = [
      *subjects, ArchUnit::RegexFactory.filename_matcher('*_client.rb')
    ]
    matching = projected_edge('lib/clients/api_client.rb', 'json')
    wrong_name = projected_edge('lib/clients/helper.rb', 'json')
    wrong_folder = projected_edge('lib/services/api_client.rb', 'json')

    violations = described_class.gather_external_module_dependency_violations(
      [matching, wrong_name, wrong_folder], subject_filters, modules, is_negated: true
    )

    expect(violations.map(&:dependency)).to eq([matching])
  end

  it 'creates immutable value-comparable violation data' do
    dependency = projected_edge('lib/client.rb', 'json')
    violation = ArchUnit::ExternalModuleDependencyViolation.new(
      dependency:, is_negated: true
    )
    equal_value = ArchUnit::ExternalModuleDependencyViolation.new(
      dependency:, is_negated: true
    )

    expect(violation).to eq(equal_value)
    expect(violation.hash).to eq(equal_value.hash)
    expect(violation).to be_frozen
  end

  it 'rejects invalid edges, filters, empty modules, and mood flags' do
    expect do
      described_class.gather_external_module_dependency_violations(
        [Object.new], subjects, modules, is_negated: false
      )
    end.to raise_error(ArgumentError, /ProjectedEdge/)
    expect do
      described_class.gather_external_module_dependency_violations(
        [], [Object.new], modules, is_negated: false
      )
    end.to raise_error(ArgumentError, /subject_filters/)
    expect do
      described_class.gather_external_module_dependency_violations(
        [], subjects, [], is_negated: false
      )
    end.to raise_error(ArgumentError, /non-empty/)
    expect do
      described_class.gather_external_module_dependency_violations(
        [], subjects, modules, is_negated: nil
      )
    end.to raise_error(ArgumentError, /true or false/)
  end
end
