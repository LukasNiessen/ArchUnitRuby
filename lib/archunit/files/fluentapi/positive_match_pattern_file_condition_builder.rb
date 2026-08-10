# frozen_string_literal: true

require_relative 'match_pattern_file_condition_builder'
require_relative 'cycle_free_file_condition'

module ArchUnit
  module Files
    module FluentApi
      # The `should` mood for file predicates.
      class PositiveMatchPatternFileConditionBuilder < MatchPatternFileConditionBuilder
        def initialize(scope)
          super(scope, negated: false)
        end

        def have_no_cycles
          CycleFreeFileCondition.new(self)
        end
      end
    end
  end
end
