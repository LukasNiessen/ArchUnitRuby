# frozen_string_literal: true

module ArchUnit
  module Layers
    module FluentApi
      # Validation and defensive copying for immutable layer policy builders.
      module LayeredArchitectureValues
        private

        def validated_layer_name(value)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, 'layer name must be a non-empty String'
        end

        def immutable_project_locator(locator)
          return if locator.nil?

          locator = locator.to_path if locator.respond_to?(:to_path)
          return locator.dup.freeze if locator.is_a?(String) && !locator.empty?

          raise ArgumentError, 'project_locator must be a non-empty path or nil'
        end

        def immutable_layer_definitions(values)
          definitions = Array(values).dup
          unless definitions.all?(Assertion::LayerDefinition)
            raise ArgumentError, 'layer_definitions must contain only LayerDefinition values'
          end
          unless definitions.map(&:name).uniq.length == definitions.length
            raise ArgumentError, 'layer names must be unique'
          end

          definitions.freeze
        end

        def immutable_dependency_map(value)
          raise ArgumentError, 'dependency policies must be Hash values' unless value.is_a?(Hash)

          value.to_h do |source, targets|
            immutable_source = validated_layer_name(source)
            immutable_targets = Array(targets).map do |name|
              validated_layer_name(name)
            end.freeze
            [immutable_source, immutable_targets]
          end.freeze
        end
      end
    end
  end
end
