# frozen_string_literal: true

require 'fileutils'
require_relative '../../common/projection/projected_edge'

module ArchUnit
  module Slices
    # Parsing and rendering of the supported PlantUML component-diagram subset.
    module Uml
      # Stable PlantUML generation and UTF-8 file export for projected slice graphs.
      module PlantUmlRenderer
        module_function

        def render(edges, components: [])
          validate_edges(edges)
          components = component_names(edges, components)
          lines = ['@startuml']
          lines.concat(components.map { |name| "  component [#{plant_uml_name(name)}]" })
          lines.concat(sorted_edges(edges).map do |edge|
            "  [#{plant_uml_name(edge.source_label)}] --> " \
              "[#{plant_uml_name(edge.target_label)}]"
          end)
          "#{lines.append('@enduml').join("\n")}\n"
        end

        def export(edges, output_path, components: [])
          path = normalized_path(output_path)
          FileUtils.mkdir_p(File.dirname(path)) unless File.dirname(path) == '.'
          File.binwrite(path, render(edges, components:).encode(Encoding::UTF_8))
          nil
        end

        def component_names(edges, values)
          edge_names = edges.flat_map { |edge| [edge.source_label, edge.target_label] }
          names = [*Array(values), *edge_names]
          names.map { |name| plant_uml_name(name) }.uniq.sort.freeze
        end
        private_class_method :component_names

        def sorted_edges(edges)
          edges.sort_by { |edge| [edge.source_label, edge.target_label] }
        end
        private_class_method :sorted_edges

        def validate_edges(value)
          return if value.is_a?(Array) && value.all?(Common::Projection::ProjectedEdge)

          raise ArgumentError, 'edges must be an Array of ProjectedEdge values'
        end
        private_class_method :validate_edges

        def plant_uml_name(value)
          valid = value.is_a?(String) && !value.strip.empty? && !value.match?(/[\]\r\n]/)
          return value.strip if valid

          raise ArgumentError, 'PlantUML component names must be non-empty and cannot contain ]'
        end
        private_class_method :plant_uml_name

        def normalized_path(value)
          value = value.to_path if value.respond_to?(:to_path)
          return value if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'output_path must be a non-empty path'
        end
        private_class_method :normalized_path
      end
    end
  end
end
