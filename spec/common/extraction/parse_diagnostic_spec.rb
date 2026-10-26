# frozen_string_literal: true

RSpec.describe ArchUnit::ParseDiagnostic do
  it 'normalizes and freezes source data without freezing caller strings' do
    path = +'app\\broken.rb'
    message = +'unexpected token'
    diagnostic = described_class.new(path:, line: 2, column: 3, message:)
    path.replace('changed.rb')
    message.replace('changed message')
    expect(diagnostic.to_h).to eq(path: 'app/broken.rb', line: 2, column: 3,
                                  message: 'unexpected token')
    expect(diagnostic.path).to be_frozen
    expect(diagnostic.message).to be_frozen
  end

  it 'rejects invalid text, coordinates, and malformed diagnostic collections' do
    valid = { path: 'file.rb', line: 1, column: 1, message: 'syntax error' }
    [{ path: nil }, { path: '' }, { message: nil }, { message: '' },
     { line: 0 }, { column: -1 }, { line: 1.5 }].each do |invalid|
      expect { described_class.new(**valid, **invalid) }.to raise_error(ArgumentError)
    end
    [nil, [], ['not a diagnostic']].each do |invalid|
      expect { ArchUnit::SourceParseError.new(invalid) }.to raise_error(ArgumentError)
    end
  end
end
