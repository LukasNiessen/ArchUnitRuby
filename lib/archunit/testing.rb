# frozen_string_literal: true

require_relative 'testing/color_utils'
require_relative 'testing/test_violation'
require_relative 'testing/test_result'
require_relative 'testing/violation_factory'
require_relative 'testing/result_factory'

# Public violation formatting entry points.
module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    module_function

    def format_violations(violations, color: nil)
      ResultFactory.from_violations(violations, color:).message
    end
  end

  def self.format_violations(violations, color: nil)
    Testing.format_violations(violations, color:)
  end
end
