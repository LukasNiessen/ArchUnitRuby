# frozen_string_literal: true

RSpec.describe ArchUnit::Files::Assertion, '.gather_matching_file_violations' do
  def node(label)
    ArchUnit::ProjectedNode.new(label:)
  end

  let(:filter) { ArchUnit::RegexFactory.filename_matcher('*_service.rb') }

  it 'flags positive disagreements and preserves the checked node and filter' do
    service = node('lib/order_service.rb')
    repository = node('lib/order_repository.rb')

    violations = described_class.gather_matching_file_violations(
      [service, repository], filter, is_negated: false
    )

    expect(violations).to contain_exactly(
      ArchUnit::Files::Assertion::FilePatternViolation.new(
        check_filter: filter, projected_node: repository
      )
    )
  end

  it 'flags negated matches through the same assertion path' do
    service = node('lib/order_service.rb')
    repository = node('lib/order_repository.rb')

    violations = described_class.gather_matching_file_violations(
      [service, repository], filter, is_negated: true
    )

    expect(violations).to contain_exactly(
      ArchUnit::Files::Assertion::FilePatternViolation.new(
        check_filter: filter, projected_node: service, is_negated: true
      )
    )
    expect(violations.first).to be_negated
  end

  it 'returns no violations when every node agrees with its mood' do
    service = node('lib/order_service.rb')
    repository = node('lib/order_repository.rb')

    expect(
      described_class.gather_matching_file_violations(
        [service], filter, is_negated: false
      )
    ).to eq([])
    expect(
      described_class.gather_matching_file_violations(
        [repository], filter, is_negated: true
      )
    ).to eq([])
  end

  it 'creates immutable, value-comparable violation data' do
    violation = ArchUnit::Files::Assertion::FilePatternViolation.new(
      check_filter: filter, projected_node: node('lib/order.rb'), is_negated: true
    )
    equal_value = ArchUnit::Files::Assertion::FilePatternViolation.new(
      check_filter: filter, projected_node: node('lib/order.rb'), is_negated: true
    )

    expect(violation).to eq(equal_value)
    expect(violation.hash).to eq(equal_value.hash)
    expect(violation).to be_frozen
  end

  it 'rejects invalid nodes, filters, and mood flags' do
    expect do
      described_class.gather_matching_file_violations([], Object.new, is_negated: false)
    end.to raise_error(ArgumentError, /check_filter/)
    expect do
      described_class.gather_matching_file_violations([Object.new], filter, is_negated: false)
    end.to raise_error(ArgumentError, /ProjectedNode/)
    expect do
      described_class.gather_matching_file_violations([], filter, is_negated: nil)
    end.to raise_error(ArgumentError, /true or false/)
  end
end
