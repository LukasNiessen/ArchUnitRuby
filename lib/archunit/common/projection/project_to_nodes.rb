# frozen_string_literal: true

require_relative '../extraction/edge'
require_relative 'projected_node'
require_relative 'project_edges'

module ArchUnit
  module Common
    # Pure functions and immutable values for relabeling dependency graphs.
    module Projection
      module_function

      def project_to_nodes(graph, include_externals: false)
        validate_include_externals(include_externals)
        labels, incoming, outgoing = collect_node_edges(graph, include_externals)

        labels.keys.sort.map do |label|
          ProjectedNode.new(label:, incoming: incoming[label], outgoing: outgoing[label])
        end.freeze
      end

      def collect_node_edges(graph, include_externals)
        incoming = Hash.new { |hash, label| hash[label] = [] }
        outgoing = Hash.new { |hash, label| hash[label] = [] }
        labels = {}

        each_edge(graph) do |edge|
          collect_node_edge(edge, labels, incoming, outgoing, include_externals)
        end
        [labels, incoming, outgoing]
      end
      private_class_method :collect_node_edges

      def collect_node_edge(edge, labels, incoming, outgoing, include_externals)
        labels[edge.source] = true
        return if self_edge?(edge)

        outgoing[edge.source] << edge
        return if edge.external && !include_externals

        labels[edge.target] = true
        incoming[edge.target] << edge
      end
      private_class_method :collect_node_edge

      def self_edge?(edge)
        edge.source == edge.target
      end
      private_class_method :self_edge?

      def validate_include_externals(value)
        return if [true, false].include?(value)

        raise ArgumentError, 'include_externals must be true or false'
      end
      private_class_method :validate_include_externals
    end
  end
end
