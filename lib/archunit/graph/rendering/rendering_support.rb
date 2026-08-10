# frozen_string_literal: true

require_relative '../projection/graph_report_snapshot'

module ArchUnit
  module GraphReporting
    module Rendering
      # Shared validation for renderers that accept only completed snapshots.
      module RenderingSupport
        module_function

        def validate_snapshot(value)
          return value if value.is_a?(Projection::GraphReportSnapshot)

          raise ArgumentError, 'snapshot must be a GraphReportSnapshot'
        end

        def node_ids(snapshot)
          snapshot.nodes.to_h { |node| [node.label, node.id] }
        end
      end
    end
  end
end
