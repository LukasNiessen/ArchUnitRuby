# frozen_string_literal: true

require_relative 'escaping'
require_relative 'rendering_support'

module ArchUnit
  module GraphReporting
    module Rendering
      # Renders a Mermaid flowchart from a report snapshot.
      module MermaidRenderer
        module_function

        def render(snapshot)
          snapshot = RenderingSupport.validate_snapshot(snapshot)
          ids = RenderingSupport.node_ids(snapshot)
          lines = ["%% #{Escaping.single_line(snapshot.title)}", 'flowchart LR']
          snapshot.nodes.each do |node|
            lines << "  #{node.id}[\"#{Escaping.mermaid_label(node.label)}\"]"
          end
          snapshot.edges.each { |edge| lines << edge_line(edge, ids) }
          lines.join("\n")
        end

        def edge_line(edge, ids)
          arrow = edge.external ? '-.->' : '-->'
          label = edge.count > 1 ? "|#{edge.count}|" : ''
          "  #{ids.fetch(edge.source)} #{arrow}#{label} #{ids.fetch(edge.target)}"
        end
        private_class_method :edge_line
      end
    end
  end
end
