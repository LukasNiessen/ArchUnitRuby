# frozen_string_literal: true

RSpec.describe ArchUnit::Common::FluentApi::Checkable do
  def rule_class(&implementation)
    Class.new do
      include ArchUnit::Common::FluentApi::Checkable

      define_method(:received_options) { @received_options }
      define_method(:perform_check, &implementation)
      private :perform_check
    end
  end

  it 'normalizes omitted options and returns a violation list' do
    rule = rule_class do |options|
      @received_options = options
      []
    end.new

    expect(rule.check).to eq([])
    expect(rule.received_options).to eq(ArchUnit::Common::FluentApi::CheckOptions.new)
  end

  it 'passes provided options to the terminal implementation' do
    options = ArchUnit::Common::FluentApi::CheckOptions.new(allow_empty_tests: true)
    violation = ArchUnit::Common::Assertion::Violation.new
    rule = rule_class { |received| [violation] if received.equal?(options) }.new

    expect(rule.check(options)).to eq([violation])
  end

  it 'rejects non-violation and non-list results' do
    expect { rule_class { |_options| true }.new.check }
      .to raise_error(TypeError, 'check must return an Array of Violation values')
    expect { rule_class { |_options| [Object.new] }.new.check }
      .to raise_error(TypeError, 'check must return an Array of Violation values')
  end

  it 'requires an included terminal to implement its execution hook' do
    rule = Class.new { include ArchUnit::Common::FluentApi::Checkable }.new

    expect { rule.check }
      .to raise_error(NotImplementedError, /must implement #perform_check/)
  end

  it 'is exposed from the gem public surface' do
    expect(ArchUnit::Checkable).to equal(described_class)
  end
end
