# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Assertion::EmptyTestViolation do
  let(:filter) { ArchUnit::Common::RegexFactory.path_matcher('lib/**/*.rb') }

  it 'is a data-only violation describing unmatched filters' do
    violation = described_class.new(filters: [filter])

    expect(violation).to be_a(ArchUnit::Common::Assertion::Violation)
    expect(violation.filters).to eq([filter])
    expect(violation.is_negated).to be(false)
    expect(violation).not_to be_negated
    expect(violation).not_to respond_to(:message)
  end

  it 'is deeply immutable against changes to its filter collection' do
    filters = [filter]
    violation = described_class.new(filters:, is_negated: true)

    filters.clear

    expect(violation).to be_frozen
    expect(violation.filters).to be_frozen
    expect(violation.filters).to eq([filter])
    expect(violation).to be_negated
  end

  it 'supports an empty filter list for an unfiltered empty project' do
    expect(described_class.new(filters: []).filters).to be_empty
  end

  it 'compares by its violation data' do
    left = described_class.new(filters: [filter], is_negated: true)
    right = described_class.new(filters: [filter], is_negated: true)

    expect(left).to eq(right)
    expect(left.hash).to eq(right.hash)
  end

  it 'validates its filters and mood flag' do
    expect { described_class.new(filters: ['lib/**/*.rb']) }
      .to raise_error(ArgumentError, 'filters must be an Array of Filter values')
    expect { described_class.new(filters: [], is_negated: nil) }
      .to raise_error(ArgumentError, 'is_negated must be true or false')
  end

  it 'is exposed from the gem public surface' do
    expect(ArchUnit::EmptyTestViolation).to equal(described_class)
  end
end
