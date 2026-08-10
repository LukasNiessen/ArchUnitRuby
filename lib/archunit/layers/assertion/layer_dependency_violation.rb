# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../../common/projection/projected_edge'

module ArchUnit
  module Layers
    # Pure assertions over dependencies between named architectural layers.
    module Assertion
      # Data describing one cross-layer edge rejected by a layer policy.
      class LayerDependencyViolation < Common::Assertion::Violation
        RULES = %i[may_only_depend_on_layers may_not_depend_on_layers].freeze

        attr_reader :dependency, :source_layer, :target_layer, :rule

        def initialize(dependency:, source_layer:, target_layer:, rule:)
          @dependency = projected_edge(dependency)
          @source_layer = layer_name(source_layer, :source_layer)
          @target_layer = layer_name(target_layer, :target_layer)
          @rule = rule_value(rule)
          super()
        end

        def ==(other)
          other.is_a?(self.class) && values == other.send(:values)
        end
        alias eql? ==

        def hash
          [self.class, *values].hash
        end

        private

        def values
          [dependency, source_layer, target_layer, rule]
        end

        def projected_edge(value)
          return value if value.is_a?(Common::Projection::ProjectedEdge)

          raise ArgumentError, 'dependency must be a ProjectedEdge'
        end

        def layer_name(value, attribute)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, "#{attribute} must be a non-empty String"
        end

        def rule_value(value)
          return value if RULES.include?(value)

          raise ArgumentError, "rule must be one of: #{RULES.join(', ')}"
        end
      end
    end
  end
end
