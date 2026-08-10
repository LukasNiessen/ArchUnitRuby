# frozen_string_literal: true

require_relative '../../common/filter'
require_relative '../../common/fluentapi/checkable'
require_relative '../../extraction/extract_graph'
require_relative '../assertion/matching_files'
require_relative 'file_rule_support'

module ArchUnit
  module Files
    module FluentApi
      # Executable file name or location predicate for either mood.
      class MatchPatternFileCondition
        include Common::FluentApi::Checkable

        attr_reader :project_locator, :filters, :check_filter, :is_negated

        def initialize(mood, check_filter:)
          validate_mood(mood)
          validate_check_filter(check_filter)
          @project_locator = mood.project_locator
          @filters = mood.filters
          @check_filter = check_filter
          @is_negated = mood.negated?
          freeze
        end

        def negated?
          is_negated
        end

        private

        def validate_mood(value)
          return if value.is_a?(MatchPatternFileConditionBuilder)

          raise ArgumentError, 'mood must be a file condition builder'
        end

        def validate_check_filter(value)
          return if value.is_a?(Common::Filter)

          raise ArgumentError, 'check_filter must be a Filter'
        end

        def perform_check(options)
          graph = ArchUnit::Extraction.extract_graph(project_locator, options:)
          nodes = FileRuleSupport.selected_nodes(graph, filters)
          empty_test = empty_test_violation(
            nodes, filters:, negated: is_negated, options:
          )
          return empty_test if empty_test

          Assertion.gather_matching_file_violations(nodes, check_filter, is_negated:)
        end
      end
    end
  end
end
