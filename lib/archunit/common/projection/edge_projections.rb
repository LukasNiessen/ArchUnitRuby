# frozen_string_literal: true

require_relative 'mapped_edge'

module ArchUnit
  module Common
    # Reusable edge-to-label mapping functions for shared graph projections.
    module Projection
      module_function

      # Maps every non-self edge without changing its labels.
      def per_edge
        lambda do |edge|
          next if edge.source == edge.target

          map_identity(edge)
        end
      end

      # Maps non-self edges whose targets are part of the extracted project.
      def per_internal_edge
        lambda do |edge|
          next if edge.external || edge.source == edge.target

          map_identity(edge)
        end
      end

      # Maps non-self edges whose targets are outside the extracted project.
      def per_external_edge
        lambda do |edge|
          next unless edge.external
          next if edge.source == edge.target

          map_identity(edge)
        end
      end

      # Maps an edge without filtering, including source-file self-edges.
      def identity
        ->(edge) { map_identity(edge) }
      end

      def map_identity(edge)
        MappedEdge.new(source_label: edge.source, target_label: edge.target)
      end
      private_class_method :map_identity
    end
  end
end
