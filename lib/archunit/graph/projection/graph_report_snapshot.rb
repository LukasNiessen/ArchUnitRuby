# frozen_string_literal: true

require_relative 'graph_report_edge'
require_relative 'graph_report_node'
require_relative 'graph_report_summary'

module ArchUnit
  module GraphReporting
    module Projection
      # Immutable graph after filtering, collapsing, aggregation, and counting.
      GraphReportSnapshot = Data.define(:title, :nodes, :edges, :summary) do
        def initialize(title:, nodes:, edges:, summary:)
          title = immutable_title(title)
          nodes = immutable_values(nodes, GraphReportNode, :nodes)
          edges = immutable_values(edges, GraphReportEdge, :edges)
          unless summary.is_a?(GraphReportSummary)
            raise ArgumentError, 'summary must be a GraphReportSummary'
          end

          super
        end

        private

        def immutable_title(value)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, 'title must be a non-empty String'
        end

        def immutable_values(values, type, attribute)
          entries = Array(values).dup
          unless entries.all?(type)
            type_name = type.name.split('::').last
            raise ArgumentError, "#{attribute} must contain only #{type_name} values"
          end

          entries.freeze
        end
      end
    end
  end
end
