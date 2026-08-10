# frozen_string_literal: true

require_relative 'test_violation'

module ArchUnit
  module Testing
    # Human-readable presentation for slice architecture violations.
    module SliceViolationFormatter
      private

      def slice_dependency(violation)
        relationship = if violation.rule == :contain_dependency
                         'depends on forbidden slice'
                       else
                         'has a dependency not allowed by the diagram on'
                       end
        TestViolation.new(
          message: 'Slice dependency violation',
          details: "Slice '#{violation.source_slice}' #{relationship} " \
                   "'#{violation.target_slice}'."
        )
      end
    end
  end
end
