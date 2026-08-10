# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../../extraction/extract_graph'
require_relative '../../extraction/locate_project'
require_relative '../assertion/custom_file_condition'
require_relative '../extraction/extract_file_info'
require_relative 'file_rule_support'

module ArchUnit
  module Files
    module FluentApi
      # Executable custom predicate evaluated against immutable FileInfo values.
      class CustomFileCondition
        include Common::FluentApi::Checkable

        attr_reader :project_locator, :subject_filters, :condition, :message, :is_negated

        def initialize(mood, condition:, message:)
          validate_mood(mood)
          @project_locator = mood.project_locator
          @subject_filters = mood.filters
          @condition = callable_value(condition)
          @message = message_value(message)
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

        def callable_value(value)
          return value if value.respond_to?(:call)

          raise ArgumentError, 'condition must be callable'
        end

        def message_value(value)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, 'message must be a non-empty String'
        end

        def perform_check(options)
          graph = ArchUnit::Extraction.extract_graph(project_locator, options:)
          nodes = FileRuleSupport.selected_nodes(graph, subject_filters)
          empty_test = FileRuleSupport.empty_test_violation(
            nodes, subject_filters, negated: is_negated, options:
          )
          return empty_test if empty_test

          Assertion.gather_custom_file_violations(
            extract_file_infos(nodes), condition, message, is_negated:
          )
        end

        def extract_file_infos(nodes)
          root = ArchUnit::Extraction.locate_project(project_locator)
          nodes.map { |node| Files::Extraction.extract_file_info(root, node.label) }
        end
      end
    end
  end
end
