# frozen_string_literal: true

RSpec.describe ArchUnit::UserError do
  it 'is a standard error representing incorrect API usage' do
    error = described_class.new('pattern must not be empty')

    expect(error).to be_a(StandardError)
    expect(error.message).to eq('pattern must not be empty')
  end

  it 'can be raised and rescued independently from technical errors' do
    expect { raise described_class, 'invalid selector' }
      .to raise_error(described_class, 'invalid selector')
    expect(described_class).not_to be < ArchUnit::TechnicalError
  end

  it 'is not an architecture rule violation' do
    expect(described_class.new).not_to be_a(ArchUnit::Violation)
  end
end
