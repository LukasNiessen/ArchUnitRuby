# frozen_string_literal: true

require_relative '../assertion/violation'
require_relative '../assertion/empty_test_violation'
require_relative 'check_options'

module ArchUnit
  module Common
    module FluentApi
      # The shared execution contract implemented by every terminal rule.
      module Checkable
        def check(options = nil)
          resolved_options = CheckOptions.resolve(options)
          violations = perform_check(resolved_options)
          validate_violations(violations)
        end

        private

        def perform_check(_options)
          raise NotImplementedError, "#{self.class} must implement #perform_check"
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
