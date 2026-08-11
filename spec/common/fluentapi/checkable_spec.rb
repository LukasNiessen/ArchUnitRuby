# frozen_string_literal: true

require 'stringio'

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

  it 'logs lifecycle, violations, and metric evidence through per-check options' do
    output = StringIO.new
    metric_violation = Class.new(ArchUnit::Violation) do
      def metric_name = :method_count
      def value = 7
      def identifier = 'lib/example.rb:Example'
    end.new
    rule = rule_class { |_options| [metric_violation] }.new
    logging = ArchUnit::LoggingOptions.new(level: :debug, io: output)

    expect(rule.check(ArchUnit::CheckOptions.new(logging:))).to eq([metric_violation])
    expect(output.string).to include(
      'start check:', 'log progress:', 'log violation:',
      'log metric: method_count=7 [lib/example.rb:Example]', 'end check:'
    )
  end

  it 'keeps logging sinks isolated between checks' do
    first_output = StringIO.new
    second_output = StringIO.new
    first = rule_class { |_options| [] }.new
    second = rule_class { |_options| [ArchUnit::Violation.new] }.new

    first.check(ArchUnit::CheckOptions.new(
                  logging: ArchUnit::LoggingOptions.new(io: first_output)
                ))
    second.check(ArchUnit::CheckOptions.new(
                   logging: ArchUnit::LoggingOptions.new(io: second_output)
                 ))

    expect(first_output.string).to include('(0 violations)')
    expect(first_output.string).not_to include('log violation:')
    expect(second_output.string).to include('(1 violations)', 'log violation:')
  end

  it 'logs a failed check at error level and preserves the original exception' do
    output = StringIO.new
    rule = rule_class { |_options| raise 'extraction failed' }.new
    options = ArchUnit::CheckOptions.new(
      logging: ArchUnit::LoggingOptions.new(level: :error, io: output)
    )

    expect { rule.check(options) }.to raise_error(RuntimeError, 'extraction failed')
    expect(output.string).to include('[ERROR] end check:', 'RuntimeError: extraction failed')
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

  it 'provides the universal empty-selection guard to terminal implementations' do
    guarded_rule_class = Class.new do
      include ArchUnit::Common::FluentApi::Checkable

      def initialize(items)
        @items = items
      end

      private

      def perform_check(options)
        empty_test_violation(
          @items, filters: [], negated: true, options:
        ) || []
      end
    end
    rule = guarded_rule_class.new([])

    expect(rule.check).to contain_exactly(
      ArchUnit::EmptyTestViolation.new(filters: [], is_negated: true)
    )
    expect(rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))).to eq([])
    expect(guarded_rule_class.new([Object.new]).check).to eq([])
  end

  it 'validates empty-selection guard inputs for future terminal implementations' do
    invalid_guard_class = Class.new do
      include ArchUnit::Common::FluentApi::Checkable

      private

      def perform_check(options)
        empty_test_violation(nil, filters: [], negated: false, options:)
      end
    end

    expect { invalid_guard_class.new.check }
      .to raise_error(ArgumentError, /respond to empty/)
  end

  it 'is exposed from the gem public surface' do
    expect(ArchUnit::Checkable).to equal(described_class)
  end
end
