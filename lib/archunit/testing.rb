# frozen_string_literal: true

require_relative 'testing/color_utils'
require_relative 'testing/test_violation'
require_relative 'testing/test_result'
require_relative 'testing/violation_factory'
require_relative 'testing/result_factory'
require_relative 'testing/assertion_failure'
require_relative 'testing/assert_passes'

# Public violation formatting entry points.
module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    module_function

    def format_violations(violations, color: nil)
      ResultFactory.from_violations(violations, color:).message
    end

    def result_for(rule, options = nil, expected_to_pass: true)
      unless rule.is_a?(Common::FluentApi::Checkable)
        raise ArgumentError, 'rule must implement Checkable'
      end

      violations = rule.check(options)
      return ResultFactory.from_violations(violations) if expected_to_pass

      ResultFactory.from_violations(violations, expected_to_pass: false)
    end
  end

  def self.format_violations(violations, color: nil)
    Testing.format_violations(violations, color:)
  end
end

require_relative 'testing/rspec_adapter'
require_relative 'testing/minitest_adapter'
