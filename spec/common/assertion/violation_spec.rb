# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Assertion::Violation do
  it 'is the immutable base type for architecture rule failures' do
    violation = described_class.new

    expect(violation).to be_a(described_class)
    expect(violation).to be_frozen
  end

  it 'is exposed from the gem public surface' do
    expect(ArchUnit::Violation).to equal(described_class)
  end
end
