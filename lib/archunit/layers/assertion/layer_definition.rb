# frozen_string_literal: true

require_relative '../../common/filter'
require_relative '../../common/pattern_matching'

module ArchUnit
  module Layers
    # Pure assertions over dependencies between named architectural layers.
    module Assertion
      # Immutable association between a layer name and its file selectors.
      class LayerDefinition
        attr_reader :name, :filters

        def initialize(name:, filters:)
          @name = layer_name(name)
          @filters = filter_values(filters)
          freeze
        end

        def matches?(file_path)
          Common::PatternMatching.matches_any_pattern?(file_path, filters)
        end

        def with_filter(filter)
          self.class.new(name:, filters: [*filters, filter])
        end

        def ==(other)
          other.is_a?(self.class) && name == other.name && filters == other.filters
        end
        alias eql? ==

        def hash
          [self.class, name, filters].hash
        end

        private

        def layer_name(value)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, 'name must be a non-empty String'
        end

        def filter_values(values)
          filters = Array(values).dup
          unless !filters.empty? && filters.all?(Common::Filter)
            raise ArgumentError, 'filters must contain at least one Filter'
          end

          filters.freeze
        end
      end
    end
  end
end
