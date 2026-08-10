# frozen_string_literal: true

require_relative '../extraction/edge'
require_relative 'mapped_edge'

module ArchUnit
  module Common
    module Projection
      # A labeled dependency that retains every raw edge collapsed into it.
      ProjectedEdge = Data.define(:source_label, :target_label, :cumulated_edges) do
        def initialize(source_label:, target_label:, cumulated_edges:)
          mapped = MappedEdge.new(source_label:, target_label:)
          cumulated_edges = immutable_edges(cumulated_edges)

          super(
            source_label: mapped.source_label,
            target_label: mapped.target_label,
            cumulated_edges:
          )
        end

        private

        def immutable_edges(values)
          edges = Array(values).dup
          unless edges.any? && edges.all?(Extraction::Edge)
            raise ArgumentError, 'cumulated_edges must contain at least one Edge'
          end

          edges.freeze
        end
      end
    end
  end
end
