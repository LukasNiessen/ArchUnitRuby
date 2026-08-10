# frozen_string_literal: true

require_relative 'd2_renderer'
require_relative 'dot_renderer'
require_relative 'escaping'
require_relative 'html_document'
require_relative 'json_renderer'
require_relative 'mermaid_renderer'
require_relative 'rendering_support'

module ArchUnit
  module GraphReporting
    module Rendering
      # Renders a complete offline HTML report with no external resources.
      module HtmlRenderer
        module_function

        def render(snapshot)
          snapshot = RenderingSupport.validate_snapshot(snapshot)
          title = Escaping.html(snapshot.title)
          format(HtmlDocument::TEMPLATE, title:, body: report_body(snapshot))
        end

        def report_body(snapshot)
          [
            summary_section(snapshot), node_section(snapshot), dependency_section(snapshot),
            source_section(snapshot)
          ].join("\n")
        end
        private_class_method :report_body

        def summary_section(snapshot)
          summary = snapshot.summary
          <<~HTML
            <section class="summary" aria-label="Graph summary">
              #{metric(summary.node_count, 'Nodes')}
              #{metric(summary.edge_count, 'Aggregated edges')}
              #{metric(summary.raw_edge_count, 'Raw edges')}
              #{metric(summary.external_edge_count, 'External edges')}
            </section>
          HTML
        end
        private_class_method :summary_section

        def metric(value, label)
          "<div class=\"metric\"><strong>#{value}</strong>#{Escaping.html(label)}</div>"
        end
        private_class_method :metric

        def node_section(snapshot)
          items = snapshot.nodes.map do |node|
            "<li><code>#{Escaping.html(node.label)}</code></li>"
          end.join
          "<section><h2>Nodes</h2><ul>#{items}</ul></section>"
        end
        private_class_method :node_section

        def dependency_section(snapshot)
          return empty_dependency_section if snapshot.edges.empty?

          rows = snapshot.edges.map { |edge| dependency_row(edge) }.join
          <<~HTML
            <section><h2>Dependencies</h2><table>
              <thead><tr><th>Source</th><th>Target</th><th>Count</th><th>External</th><th>Import kinds</th></tr></thead>
              <tbody>#{rows}</tbody>
            </table></section>
          HTML
        end
        private_class_method :dependency_section

        def dependency_row(edge)
          values = [
            edge.source, edge.target, edge.count,
            edge.external ? 'yes' : 'no', edge.import_kinds.join(', ')
          ]
          "<tr>#{values.map { |value| "<td>#{Escaping.html(value)}</td>" }.join}</tr>"
        end
        private_class_method :dependency_row

        def empty_dependency_section
          '<section><h2>Dependencies</h2><div class="empty">' \
            'No dependency edges matched this graph query.</div></section>'
        end
        private_class_method :empty_dependency_section

        def source_section(snapshot)
          sources = {
            'Mermaid' => MermaidRenderer.render(snapshot),
            'DOT' => DotRenderer.render(snapshot),
            'D2' => D2Renderer.render(snapshot),
            'JSON snapshot' => JsonRenderer.render(snapshot)
          }
          details = sources.map do |name, source|
            "<details><summary>#{name}</summary><pre>#{Escaping.html(source)}</pre></details>"
          end.join
          "<section><h2>Portable sources</h2>#{details}</section>"
        end
        private_class_method :source_section
      end
    end
  end
end
