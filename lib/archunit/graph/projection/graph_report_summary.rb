# frozen_string_literal: true

module ArchUnit
  module GraphReporting
    module Projection
      # Counts describing the selected and aggregated graph snapshot.
      GraphReportSummary = Data.define(
        :node_count, :edge_count, :raw_edge_count, :external_edge_count
      ) do
        def initialize(node_count:, edge_count:, raw_edge_count:, external_edge_count:)
          values = { node_count:, edge_count:, raw_edge_count:, external_edge_count: }
          invalid = values.find { |_name, value| !value.is_a?(Integer) || value.negative? }
          raise ArgumentError, "#{invalid.first} must be a non-negative Integer" if invalid

          super
        end
      end
    end
  end
end
