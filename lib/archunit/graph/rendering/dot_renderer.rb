# frozen_string_literal: true

require_relative 'escaping'
require_relative 'rendering_support'

module ArchUnit
  module GraphReporting
    module Rendering
      # Renders a Graphviz DOT directed graph from a report snapshot.
      module DotRenderer
        module_function

        def render(snapshot)
          snapshot = RenderingSupport.validate_snapshot(snapshot)
          lines = header(snapshot)
          snapshot.nodes.each { |node| lines << "  #{Escaping.quoted(node.label)};" }
          snapshot.edges.each { |edge| lines << edge_line(edge) }
          lines << '}'
          lines.join("\n")
        end

        def header(snapshot)
          [
            'digraph dependencies {',
            '  rankdir=LR;',
            "  label=#{Escaping.quoted(snapshot.title)};",
            '  labelloc=t;'
          ]
        end
        private_class_method :header

        def edge_line(edge)
          attributes = edge_attributes(edge)
          suffix = attributes.empty? ? '' : " [#{attributes.join(', ')}]"
          "  #{Escaping.quoted(edge.source)} -> #{Escaping.quoted(edge.target)}#{suffix};"
        end
        private_class_method :edge_line

        def edge_attributes(edge)
          attributes = []
          attributes << "label=#{Escaping.quoted(edge.count.to_s)}" if edge.count > 1
          attributes << 'style=dashed' if edge.external
          return attributes if edge.import_kinds.empty?

          attributes << "tooltip=#{Escaping.quoted(edge.import_kinds.join(', '))}"
        end
        private_class_method :edge_attributes
      end
    end
  end
end
