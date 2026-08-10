# frozen_string_literal: true

require_relative 'cycles/johnson_cycles'
require_relative 'edge_projections'
require_relative 'project_edges'
require_relative 'projected_edge'

module ArchUnit
  module Common
    # Cycle projection over immutable, evidence-retaining projected edges.
    module Projection
      module_function

      def project_internal_cycles(graph)
        project_cycles(project_edges(graph, per_internal_edge))
      end

      def project_cycles(edges)
        projected_edges = normalize_projected_edges(edges)
        label_ids = label_ids_for(projected_edges)
        edges_by_ids = index_edges(projected_edges, label_ids)
        paths = Cycles::JohnsonCycles.call(adjacency_for(edges_by_ids))
        cycles_from_paths(paths, edges_by_ids)
      end

      def cycles_from_paths(paths, edges_by_ids)
        paths.map do |path|
          path.each_index.map do |index|
            source = path.fetch(index)
            target = path.fetch((index + 1) % path.length)
            edges_by_ids.fetch([source, target])
          end.freeze
        end.freeze
      end

      def normalize_projected_edges(edges)
        unless edges.respond_to?(:each)
          raise ArgumentError, 'edges must be an enumerable of ProjectedEdge values'
        end

        groups = {}
        edges.each { |edge| add_to_projection_groups(groups, edge) }
        projected_edges_from(groups)
      end
      private_class_method :normalize_projected_edges

      def add_to_projection_groups(groups, edge)
        unless edge.is_a?(ProjectedEdge)
          raise ArgumentError, 'edges must contain only ProjectedEdge values'
        end
        return if edge.source_label == edge.target_label

        key = [edge.source_label, edge.target_label]
        (groups[key] ||= []).concat(edge.cumulated_edges)
      end
      private_class_method :add_to_projection_groups

      def projected_edges_from(groups)
        groups.map do |(source_label, target_label), raw_edges|
          ProjectedEdge.new(
            source_label:, target_label:, cumulated_edges: raw_edges.uniq
          )
        end.freeze
      end
      private_class_method :projected_edges_from

      def label_ids_for(edges)
        labels = edges.flat_map { |edge| [edge.source_label, edge.target_label] }.uniq
        labels.each_with_index.to_h.freeze
      end
      private_class_method :label_ids_for

      def index_edges(edges, label_ids)
        edges.to_h do |edge|
          key = [label_ids.fetch(edge.source_label), label_ids.fetch(edge.target_label)]
          [key, edge]
        end.freeze
      end
      private_class_method :index_edges

      def adjacency_for(edges_by_ids)
        adjacency = Hash.new { |hash, vertex| hash[vertex] = [] }
        edges_by_ids.each_key do |source, target|
          adjacency[source] << target
          adjacency[target] ||= []
        end
        adjacency.transform_values { |targets| targets.uniq.freeze }.freeze
      end
      private_class_method :adjacency_for
    end
  end
end
