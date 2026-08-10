# frozen_string_literal: true

require_relative 'csv_renderer'
require_relative 'd2_renderer'
require_relative 'dot_renderer'
require_relative 'export_report'
require_relative 'html_renderer'
require_relative 'json_renderer'
require_relative 'mermaid_renderer'

module ArchUnit
  module GraphReporting
    module Rendering
      # One dispatch point for every renderer consuming the shared snapshot.
      class GraphRenderer
        RENDERERS = {
          dot: DotRenderer, mermaid: MermaidRenderer, d2: D2Renderer,
          csv: CsvRenderer, json: JsonRenderer, html: HtmlRenderer
        }.freeze

        class << self
          def render(snapshot, format)
            renderer(format).render(snapshot)
          end

          def export(snapshot, format, output_path)
            ExportReport.write(output_path, render(snapshot, format))
          end

          RENDERERS.each_key do |format|
            define_method("to_#{format}") do |snapshot|
              render(snapshot, format)
            end

            define_method("export_as_#{format}") do |snapshot, output_path|
              export(snapshot, format, output_path)
            end
          end

          private

          def renderer(format)
            key = format.respond_to?(:to_sym) ? format.to_sym : format
            RENDERERS.fetch(key)
          rescue KeyError
            raise ArgumentError, "unknown graph report format: #{format.inspect}"
          end
        end

        private_class_method :new
      end
    end
  end
end
