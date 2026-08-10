# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../../common/projection/edge_projections'
require_relative '../../common/projection/project_edges'
require_relative '../../common/regex_factory'
require_relative '../../extraction/extract_graph'
require_relative '../assertion/depend_on_external_modules'
require_relative 'file_rule_support'

module ArchUnit
  module Files
    module FluentApi
      # Executable external-module rule with OR-combined module selectors.
      class DependOnExternalModuleCondition
        include Common::FluentApi::Checkable

        attr_reader :builder, :project_locator, :subject_filters, :module_filters, :is_negated

        def initialize(builder, module_filters:)
          unless builder.is_a?(DependOnExternalModuleConditionBuilder)
            raise ArgumentError, 'builder must be a DependOnExternalModuleConditionBuilder'
          end

          @builder = builder
          @project_locator = builder.project_locator
          @subject_filters = builder.subject_filters
          @module_filters = immutable_module_filters(module_filters)
          @is_negated = builder.negated?
          freeze
        end

        def negated?
          is_negated
        end

        def matching(module_name)
          filter = Common::RegexFactory.path_matcher(module_name)
          self.class.new(builder, module_filters: [*module_filters, filter])
        end

        private

        def immutable_module_filters(values)
          filters = Array(values).dup
          unless !filters.empty? && filters.all?(Common::Filter)
            raise ArgumentError, 'module_filters must contain at least one Filter'
          end

          filters.freeze
        end

        def perform_check(options)
          graph = Extraction.extract_graph(project_locator, options:)
          nodes = FileRuleSupport.selected_nodes(graph, subject_filters)
          empty_test = FileRuleSupport.empty_test_violation(
            nodes, subject_filters, negated: is_negated, options:
          )
          return empty_test if empty_test

          edges = Common::Projection.project_edges(graph, Common::Projection.per_external_edge)
          Assertion.gather_external_module_dependency_violations(
            edges, subject_filters, module_filters, is_negated:
          )
        end
      end
    end
  end
end
