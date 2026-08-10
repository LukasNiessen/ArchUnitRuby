# frozen_string_literal: true

require_relative 'escaping'
require_relative 'rendering_support'

module ArchUnit
  module GraphReporting
    module Rendering
      # Renders D2 diagram source from a report snapshot.
      module D2Renderer
        module_function

        def render(snapshot)
          snapshot = RenderingSupport.validate_snapshot(snapshot)
          lines = ["# #{Escaping.single_line(snapshot.title)}"]
          snapshot.nodes.each { |node| lines << Escaping.quoted(node.label) }
          snapshot.edges.each { |edge| lines << edge_line(edge) }
          lines.join("\n")
        end

        def edge_line(edge)
          label = edge.count > 1 ? ": #{Escaping.quoted(edge.count.to_s)}" : ''
          style = edge.external ? ' { style.stroke-dash: 4 }' : ''
          "#{Escaping.quoted(edge.source)} -> #{Escaping.quoted(edge.target)}#{label}#{style}"
        end
        private_class_method :edge_line
      end
    end
  end
end
