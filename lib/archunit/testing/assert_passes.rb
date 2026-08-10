# frozen_string_literal: true

require_relative '../common/fluentapi/checkable'
require_relative 'assertion_failure'
require_relative 'result_factory'

# Public framework-neutral architecture assertion entry point.
module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    module_function

    def assert_passes(rule, options = nil)
      unless rule.is_a?(Common::FluentApi::Checkable)
        raise ArgumentError, 'rule must implement Checkable'
      end

      result = ResultFactory.from_violations(rule.check(options))
      return if result.passed?

      raise AssertionFailure, result
    end
  end

  def self.assert_passes(rule, options = nil)
    Testing.assert_passes(rule, options)
  end
end
