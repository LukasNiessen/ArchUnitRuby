# frozen_string_literal: true

require_relative 'match_pattern_file_condition_builder'

module ArchUnit
  module Files
    module FluentApi
      # The `should` mood for file predicates.
      class PositiveMatchPatternFileConditionBuilder < MatchPatternFileConditionBuilder
        def initialize(scope)
          super(scope, negated: false)
        end
      end
    end
  end
end
