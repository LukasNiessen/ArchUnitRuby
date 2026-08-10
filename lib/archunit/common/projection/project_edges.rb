# frozen_string_literal: true

require_relative '../extraction/edge'
require_relative 'mapped_edge'
require_relative 'projected_edge'

module ArchUnit
  module Common
    # Pure functions and immutable values for relabeling dependency graphs.
    module Projection
      module_function

      # Applies a callable Edge -> MappedEdge/nil hook and cumulates equal labels.
      def project_edges(graph, mapper = nil, &block)
        map_function = resolve_map_function(mapper, block)
        projection_groups(graph, map_function).map do |(source_label, target_label), edges|
          ProjectedEdge.new(source_label:, target_label:, cumulated_edges: edges)
        end.freeze
      end

      def projection_groups(graph, map_function)
        groups = {}

        each_edge(graph) do |edge|
          mapped = map_function.call(edge)
          next if mapped.nil?

          validate_mapped_edge(mapped)
          key = [mapped.source_label, mapped.target_label]
          (groups[key] ||= []) << edge
        end
        groups
      end
      private_class_method :projection_groups

      def resolve_map_function(mapper, block)
        raise ArgumentError, 'provide a mapper or a block, not both' if mapper && block

        map_function = mapper || block
        return map_function if map_function.respond_to?(:call)

        raise ArgumentError, 'mapper must be callable'
      end
      private_class_method :resolve_map_function

      def each_edge(graph)
        unless graph.respond_to?(:each)
          raise ArgumentError, 'graph must be an enumerable of Edge values'
        end

        graph.each do |edge|
          unless edge.is_a?(Extraction::Edge)
            raise ArgumentError, 'graph must contain only Edge values'
          end

          yield edge
        end
      end
      private_class_method :each_edge

      def validate_mapped_edge(value)
        return if value.is_a?(MappedEdge)

        raise ArgumentError, 'mapper must return a MappedEdge or nil'
      end
      private_class_method :validate_mapped_edge
    end
  end
end
