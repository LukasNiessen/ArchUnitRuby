# frozen_string_literal: true

require_relative 'match_pattern_file_condition_builder'

module ArchUnit
  module Files
    module FluentApi
      # The `should_not` mood for file predicates.
      class NegatedMatchPatternFileConditionBuilder < MatchPatternFileConditionBuilder
        def initialize(scope)
          super(scope, negated: true)
        end
      end
    end
  end
end
