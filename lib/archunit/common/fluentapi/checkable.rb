# frozen_string_literal: true

require_relative '../assertion/violation'
require_relative '../assertion/empty_test_violation'
require_relative '../logging/check_logger'
require_relative 'check_options'

module ArchUnit
  module Common
    module FluentApi
      # The shared execution contract implemented by every terminal rule.
      module Checkable
        def check(options = nil)
          resolved_options = CheckOptions.resolve(options)
          logger = Logging::CheckLogger.new(resolved_options.logging)
          check_name = self.class.name || self.class.to_s
          logger.start_check(check_name)
          execute_check(resolved_options, logger, check_name)
        ensure
          logger&.close
        end

        private

        def perform_check(_options)
          raise NotImplementedError, "#{self.class} must implement #perform_check"
        end

        def execute_check(options, logger, check_name)
          logger.log_progress("executing #{check_name}")
          violations = validate_violations(perform_check(options))
          log_violations(logger, violations)
          logger.end_check(check_name, violation_count: violations.length)
          violations
        rescue StandardError, NotImplementedError => e
          logger.end_check(check_name, error: e)
          raise
        end

        def log_violations(logger, violations)
          violations.each do |violation|
            logger.log_violation(violation)
            next unless violation.respond_to?(:metric_name) && violation.respond_to?(:value)

            subject = violation.identifier if violation.respond_to?(:identifier)
            logger.log_metric(name: violation.metric_name, value: violation.value, subject:)
          end
        end

        def empty_test_violation(selected_items, filters:, negated:, options:)
          unless selected_items.respond_to?(:empty?)
            raise ArgumentError, 'selected_items must respond to empty?'
          end
          unless options.is_a?(CheckOptions)
            raise ArgumentError, 'options must be a CheckOptions value'
          end
          return if !selected_items.empty? || options.allow_empty_tests?

          [Assertion::EmptyTestViolation.new(filters:, is_negated: negated)]
        end

        def validate_violations(violations)
          return violations if violations.is_a?(Array) && violations.all?(Assertion::Violation)

          raise TypeError, 'check must return an Array of Violation values'
        end
      end
    end
  end
end
