# frozen_string_literal: true

module ArchUnit
  module Files
    module FluentApi
      # Shared immutable state for positive and negated file predicate builders.
      class MatchPatternFileConditionBuilder
        attr_reader :project_locator, :filters

        def initialize(scope, negated:)
          unless scope.is_a?(FileConditionBuilder)
            raise ArgumentError, 'scope must be a FileConditionBuilder'
          end
          unless [true, false].include?(negated)
            raise ArgumentError, 'negated must be true or false'
          end

          @project_locator = scope.project_locator
          @filters = scope.filters
          @negated = negated
          freeze
        end

        def negated?
          @negated
        end
      end
    end
  end
end
