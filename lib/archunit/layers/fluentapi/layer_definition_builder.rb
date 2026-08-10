# frozen_string_literal: true

require_relative '../../common/regex_factory'

module ArchUnit
  module Layers
    module FluentApi
      # Immutable stage defining which files belong to one named layer.
      class LayerDefinitionBuilder
        attr_reader :architecture, :layer_name

        def initialize(architecture, layer_name)
          @architecture = architecture_value(architecture)
          @layer_name = layer_name_value(layer_name)
          freeze
        end

        def defined_by(pattern)
          add_filter(Common::RegexFactory.path_matcher(pattern))
        end

        def defined_by_folder(pattern)
          add_filter(Common::RegexFactory.folder_matcher(pattern))
        end

        private

        def add_filter(filter)
          architecture.__send__(:with_layer_filter, layer_name, filter)
        end

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
