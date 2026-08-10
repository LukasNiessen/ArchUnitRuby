# frozen_string_literal: true

module ArchUnit
  module Slices
    # Parsing and rendering of the supported PlantUML component-diagram subset.
    module Uml
      # One allowed directed component dependency from a PlantUML diagram.
      PlantUmlDependency = Data.define(:source, :target) do
        def initialize(source:, target:)
          source = component_name(source, :source)
          target = component_name(target, :target)
          super
        end

        private

        def component_name(value, attribute)
          return value.strip.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, "#{attribute} must be a non-empty component name"
        end
      end
    end
  end
end
