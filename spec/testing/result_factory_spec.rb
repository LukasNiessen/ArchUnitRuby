# frozen_string_literal: true

RSpec.describe ArchUnit::Testing::ResultFactory do
  it 'returns an immutable passing result for an empty violation list' do
    result = described_class.from_violations([], color: false)

    expect(result).to have_attributes(
      passed?: true,
      failed?: false,
      message: 'No architecture violations found.'
    )
    expect(result).to be_frozen
    expect(result.message).to be_frozen
  end

  it 'numbers every formatted violation with correct singular grammar' do
    violation = ArchUnit::EmptyTestViolation.new(filters: [])
    result = described_class.from_violations([violation], color: false)

    expect(result).to be_failed
    expect(result.message).to start_with('Found 1 architecture violation:')
    expect(result.message).to include(
      '1. No files matched the rule scope',
      'The unfiltered rule scope contained no files.'
    )
  end

  it 'preserves order and uses plural grammar for several violations' do
    first = ArchUnit::EmptyTestViolation.new(filters: [])
    second = ArchUnit::Violation.new
    message = described_class.from_violations([first, second], color: false).message

    expect(message).to start_with('Found 2 architecture violations:')
    expect(message.index('1. No files matched')).to be < message.index('2. Architecture violation')
  end

  it 'optionally adds ANSI colour without changing the prose' do
    violation = ArchUnit::EmptyTestViolation.new(filters: [])
    colored = described_class.from_violations([violation], color: true).message
    plain = described_class.from_violations([violation], color: false).message

    expect(colored).to include("\e[")
    expect(colored.gsub(/\e\[\d+m/, '')).to eq(plain)
  end

  it 'shapes a negated framework expectation without adapter-owned prose' do
    violation = ArchUnit::EmptyTestViolation.new(filters: [])

    expect(described_class.from_violations(
             [violation], color: false, expected_to_pass: false
           )).to be_passed
    result = described_class.from_violations([], color: false, expected_to_pass: false)
    expect(result).to be_failed
    expect(result.message).to eq('Expected architecture violations, but none were found.')
  end

  it 'validates violation collections, colour options, and TestResult values' do
    expect { described_class.from_violations([Object.new]) }
      .to raise_error(ArgumentError, /Violation/)
    expect { described_class.from_violations([], color: :always) }
      .to raise_error(ArgumentError, /color/)
    expect { described_class.from_violations([], expected_to_pass: nil) }
      .to raise_error(ArgumentError, /expected_to_pass/)
    expect { ArchUnit::TestResult.new(passed: nil, message: 'message') }
      .to raise_error(ArgumentError, /passed/)
    expect { ArchUnit::TestResult.new(passed: true, message: '') }
      .to raise_error(ArgumentError, /message/)
  end

  it 'exposes plain formatted messages from the public API' do
    violation = ArchUnit::EmptyTestViolation.new(filters: [])

    expect(ArchUnit.format_violations([violation], color: false)).to eq(
      described_class.from_violations([violation], color: false).message
    )
  end
end
