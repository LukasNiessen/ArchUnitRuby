# frozen_string_literal: true

require_relative '../common/assertion/violation'
require_relative 'color_utils'
require_relative 'test_result'
require_relative 'violation_factory'

module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    # Shapes a violation collection into one framework-neutral test result.
    class ResultFactory
      class << self
        def from_violations(violations, color: nil, expected_to_pass: true)
          validate_violations(violations)
          validate_expected_to_pass(expected_to_pass)
          color = resolve_color(color)
          return empty_result(color, expected_to_pass) if violations.empty?

          failing_result(violations, color, expected_to_pass)
        end

        private

        def passing_result(color)
          message = ColorUtils.green('No architecture violations found.', enabled: color)
          TestResult.new(passed: true, message:)
        end

        def empty_result(color, expected_to_pass)
          return passing_result(color) if expected_to_pass

          message = 'Expected architecture violations, but none were found.'
          message = ColorUtils.bold(ColorUtils.red(message, enabled: color), enabled: color)
          TestResult.new(passed: false, message:)
        end

        def failing_result(violations, color, expected_to_pass)
          test_violations = violations.map do |violation|
            ViolationFactory.from_violation(violation)
          end
          TestResult.new(
            passed: !expected_to_pass,
            message: failure_message(test_violations, color)
          )
        end

        def failure_message(test_violations, color)
          lines = [failure_title(test_violations.length, color), '']

          test_violations.each_with_index do |violation, index|
            append_violation(lines, violation, index, color)
          end
          lines.join("\n").rstrip
        end

        def failure_title(count, color)
          noun = count == 1 ? 'violation' : 'violations'
          title = "Found #{count} architecture #{noun}:"
          ColorUtils.bold(ColorUtils.red(title, enabled: color), enabled: color)
        end

        def append_violation(lines, violation, index, color)
          heading = "  #{index + 1}. #{violation.message}"
          lines << ColorUtils.yellow(heading, enabled: color)
          lines << "     #{violation.details}"
          lines << ''
        end

        def validate_violations(values)
          return if values.is_a?(Array) && values.all?(Common::Assertion::Violation)

          raise ArgumentError, 'violations must be an Array of Violation values'
        end

        def validate_expected_to_pass(value)
          return if [true, false].include?(value)

          raise ArgumentError, 'expected_to_pass must be true or false'
        end

        def resolve_color(value)
          return ColorUtils.supported? if value.nil?
          return value if [true, false].include?(value)

          raise ArgumentError, 'color must be true, false, or nil'
        end
      end

      private_class_method :new
    end
  end
end
