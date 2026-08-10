# frozen_string_literal: true

require_relative 'plant_uml_diagram'

module ArchUnit
  module Slices
    # Parsing and rendering of the supported PlantUML component-diagram subset.
    module Uml
      # Line-based parser for PlantUML component declarations and directed arrows.
      module PlantUmlParser
        COMPONENT = /\Acomponent\s+\[([^\]]+)\]/i
        DEPENDENCY = /\A\[([^\]]+)\]\s*-{1,2}>\s*\[([^\]]+)\]/

        module_function

        def parse(text)
          unless text.is_a?(String) && !text.strip.empty?
            raise ArgumentError, 'diagram text must be a non-empty String'
          end

          components = []
          dependencies = []
          text.each_line do |line|
            parse_line(line, components, dependencies)
          end
          PlantUmlDiagram.new(components:, dependencies:)
        end

        def parse_line(line, components, dependencies)
          line = uncommented(line)
          return if line.empty? || line.start_with?('@')

          if (match = COMPONENT.match(line))
            components << match[1]
          elsif (match = DEPENDENCY.match(line))
            dependency = PlantUmlDependency.new(source: match[1], target: match[2])
            dependencies << dependency
            components.push(dependency.source, dependency.target)
          end
        end
        private_class_method :parse_line

        def uncommented(line)
          stripped = line.strip
          return '' if stripped.start_with?("'", '//')

          stripped.split("'", 2).first.to_s.strip
        end
        private_class_method :uncommented
      end
    end
  end
end
