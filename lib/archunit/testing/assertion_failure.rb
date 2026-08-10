# frozen_string_literal: true

require_relative 'test_result'

module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    # Framework-neutral assertion failure used by the documented fallback helper.
    class AssertionFailure < StandardError
      attr_reader :result

      def initialize(result)
        unless result.is_a?(TestResult) && result.failed?
          raise ArgumentError, 'result must be a failed TestResult'
        end

        @result = result
        super(result.message)
      end
    end
  end
end
