# frozen_string_literal: true

require 'json'
require_relative 'rendering_support'

module ArchUnit
  module GraphReporting
    module Rendering
      # Renders the complete graph snapshot as stable, formatted JSON.
      module JsonRenderer
        module_function

        def render(snapshot)
          snapshot = RenderingSupport.validate_snapshot(snapshot)
          JSON.pretty_generate(snapshot_hash(snapshot))
        end

        def snapshot_hash(snapshot)
          {
            title: snapshot.title,
            nodes: snapshot.nodes.map { |node| { id: node.id, label: node.label } },
            edges: snapshot.edges.map { |edge| edge_hash(edge) },
            summary: snapshot.summary.to_h
          }
        end
        private_class_method :snapshot_hash

        def edge_hash(edge)
          {
            source: edge.source, target: edge.target, count: edge.count,
            external: edge.external, import_kinds: edge.import_kinds
          }
        end
        private_class_method :edge_hash
      end
    end
  end
end
