# frozen_string_literal: true

module ArchUnit
  module Layers
    module FluentApi
      # Immutable stage adding an allowlist or blocklist policy for one layer.
      class LayerDependencyRuleBuilder
        attr_reader :architecture, :layer_name

        def initialize(architecture, layer_name)
          @architecture = architecture_value(architecture)
          @layer_name = layer_name_value(layer_name)
          freeze
        end

        def may_only_depend_on_layers(*layer_names)
          architecture.__send__(:with_allowed_dependencies, layer_name, layer_names)
        end

        def may_not_depend_on_layers(*layer_names)
          if layer_names.empty?
            raise ArgumentError, 'may_not_depend_on_layers requires at least one layer name'
          end

          architecture.__send__(:with_forbidden_dependencies, layer_name, layer_names)
        end

        private

        def architecture_value(value)
          return value if value.is_a?(LayeredArchitecture)

          raise ArgumentError, 'architecture must be a LayeredArchitecture'
        end

        def layer_name_value(value)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, 'layer_name must be a non-empty String'
        end
      end
    end
  end
end
