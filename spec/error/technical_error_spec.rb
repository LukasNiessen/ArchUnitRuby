# frozen_string_literal: true

RSpec.describe ArchUnit::TechnicalError do
  it 'is a standard error representing library or environment failures' do
    error = described_class.new('Prism failed to initialize')

    expect(error).to be_a(StandardError)
    expect(error.message).to eq('Prism failed to initialize')
  end

  it 'can be raised and rescued specifically' do
    expect { raise described_class, 'project is unreadable' }
      .to raise_error(described_class, 'project is unreadable')
  end

  it 'is not an architecture rule violation' do
    expect(described_class.new).not_to be_a(ArchUnit::Violation)
  end
end
