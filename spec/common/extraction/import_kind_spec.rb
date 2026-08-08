# frozen_string_literal: true

RSpec.describe ArchUnit::Common::Extraction::ImportKind do
  it 'defines the Ruby dependency vocabulary' do
    expect(described_class::ALL).to contain_exactly(
      :require,
      :require_relative,
      :autoload,
      :load
    )
  end

  it 'recognizes only supported import kinds' do
    expect(described_class.valid?(:require)).to be(true)
    expect(described_class.valid?(:dynamic)).to be(false)
  end
end
