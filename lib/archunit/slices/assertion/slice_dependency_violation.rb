# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../../common/projection/projected_edge'

module ArchUnit
  module Slices
    # Pure assertions over projected slice dependencies.
    module Assertion
      # Structured evidence for a dependency rejected by a slice rule.
      class SliceDependencyViolation < Common::Assertion::Violation
        RULES = %i[contain_dependency adhere_to_diagram].freeze

        attr_reader :dependency, :source_slice, :target_slice, :rule, :is_negated

        def initialize(dependency:, source_slice:, target_slice:, rule:, is_negated:)
          @dependency = projected_edge(dependency)
          @source_slice = slice_name(source_slice, :source_slice)
          @target_slice = slice_name(target_slice, :target_slice)
          @rule = rule_value(rule)
          @is_negated = boolean(is_negated, :is_negated)
          super()
        end

        def negated?
          is_negated
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
          [dependency, source_slice, target_slice, rule, is_negated]
        end

        def projected_edge(value)
          return value if value.is_a?(Common::Projection::ProjectedEdge)

          raise ArgumentError, 'dependency must be a ProjectedEdge'
        end

        def slice_name(value, attribute)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, "#{attribute} must be a non-empty String"
        end

        def rule_value(value)
          return value if RULES.include?(value)

          raise ArgumentError, "rule must be one of: #{RULES.join(', ')}"
        end

        def boolean(value, attribute)
          return value if [true, false].include?(value)

          raise ArgumentError, "#{attribute} must be true or false"
        end
      end
    end
  end
end
