# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../../common/projection/edge_projections'
require_relative '../../common/projection/project_cycles'
require_relative '../../common/projection/project_edges'
require_relative '../../extraction/extract_graph'
require_relative '../assertion/cycle_free'
require_relative 'file_rule_support'

module ArchUnit
  module Files
    module FluentApi
      # Executable positive rule requiring the selected file graph to be acyclic.
      class CycleFreeFileCondition
        include Common::FluentApi::Checkable

        attr_reader :project_locator, :filters

        def initialize(mood)
          unless mood.is_a?(PositiveMatchPatternFileConditionBuilder)
            raise ArgumentError, 'mood must be a positive file condition builder'
          end

          @project_locator = mood.project_locator
          @filters = mood.filters
          freeze
        end

        private

        def perform_check(options)
          graph = ArchUnit::Extraction.extract_graph(project_locator, options:)
          nodes = FileRuleSupport.selected_nodes(graph, filters)
          empty_test = FileRuleSupport.empty_test_violation(
            nodes, filters, negated: false, options:
          )
          return empty_test if empty_test

          cycles = cycles_within(graph, nodes)
          Assertion.gather_cycle_violations(cycles)
        end

        def cycles_within(graph, nodes)
          selected_labels = nodes.to_h { |node| [node.label, true] }
          edges = Common::Projection.project_edges(graph, Common::Projection.per_internal_edge)
                                    .select do |edge|
            selected_labels[edge.source_label] && selected_labels[edge.target_label]
          end
          Common::Projection.project_cycles(edges)
        end
      end
    end
  end
end
