# frozen_string_literal: true

require_relative 'plant_uml_dependency'

module ArchUnit
  module Slices
    # Parsing and rendering of the supported PlantUML component-diagram subset.
    module Uml
      # Immutable component names and allowed directed dependencies parsed from PlantUML.
      PlantUmlDiagram = Data.define(:components, :dependencies) do
        def initialize(components: [], dependencies: [])
          dependencies = immutable_dependencies(dependencies)
          components = immutable_components(components, dependencies)
          super
        end

        def allows?(source, target)
          dependencies.include?(PlantUmlDependency.new(source:, target:))
        end

        private

        def immutable_dependencies(values)
          dependencies = Array(values).dup
          unless dependencies.all?(PlantUmlDependency)
            raise ArgumentError, 'dependencies must contain only PlantUmlDependency values'
          end

          dependencies.uniq.freeze
        end

        def immutable_components(values, dependencies)
          dependency_names = dependencies.flat_map { |item| [item.source, item.target] }
          components = [*Array(values), *dependency_names]
          unless components.all? { |name| name.is_a?(String) && !name.strip.empty? }
            raise ArgumentError, 'components must contain only non-empty Strings'
          end

          components.map { |name| name.strip.freeze }.uniq.freeze
        end
      end
    end
  end
end
