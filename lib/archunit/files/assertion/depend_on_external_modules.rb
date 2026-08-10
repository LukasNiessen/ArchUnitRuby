# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../../common/filter'
require_relative '../../common/pattern_matching'
require_relative '../../common/projection/projected_edge'

module ArchUnit
  module Files
    # Pure assertions over dependencies from project files to external modules.
    module Assertion
      # Data describing an external module dependency that disagrees with a rule.
      class ExternalModuleDependencyViolation < Common::Assertion::Violation
        attr_reader :dependency, :is_negated

        def initialize(dependency:, is_negated: false)
          @dependency = projected_edge(dependency)
          @is_negated = boolean_value(is_negated)
          super()
        end

        def negated?
          is_negated
        end

        def ==(other)
          other.is_a?(self.class) &&
            dependency == other.dependency &&
            is_negated == other.is_negated
        end
        alias eql? ==

        def hash
          [self.class, dependency, is_negated].hash
        end

        private

        def projected_edge(value)
          return value if value.is_a?(Common::Projection::ProjectedEdge)

          raise ArgumentError, 'dependency must be a ProjectedEdge'
        end

        def boolean_value(value)
          return value if [true, false].include?(value)

          raise ArgumentError, 'is_negated must be true or false'
        end
      end

      module_function

      def gather_external_module_dependency_violations(
        edges, subject_filters, module_filters, is_negated:
      )
        validate_external_dependency_arguments(
          edges, subject_filters, module_filters, is_negated
        )

        edges.filter_map do |edge|
          external_dependency_violation(
            edge, subject_filters, module_filters, is_negated
          )
        end
      end

      def external_dependency_violation(edge, subject_filters, module_filters, is_negated)
        return unless Common::PatternMatching.matches_all_patterns?(
          edge.source_label, subject_filters
        )

        target_matches = Common::PatternMatching.matches_any_pattern?(
          edge.target_label, module_filters
        )
        return unless is_negated ? target_matches : !target_matches

        ExternalModuleDependencyViolation.new(dependency: edge, is_negated:)
      end
      private_class_method :external_dependency_violation

      def validate_external_dependency_arguments(
        edges, subject_filters, module_filters, is_negated
      )
        validate_external_projected_edges(edges)
        validate_external_filters(subject_filters, :subject_filters, allow_empty: true)
        validate_external_filters(module_filters, :module_filters, allow_empty: false)
        return if [true, false].include?(is_negated)

        raise ArgumentError, 'is_negated must be true or false'
      end
      private_class_method :validate_external_dependency_arguments

      def validate_external_projected_edges(values)
        return if values.is_a?(Array) && values.all?(Common::Projection::ProjectedEdge)

        raise ArgumentError, 'edges must be an Array of ProjectedEdge values'
      end
      private_class_method :validate_external_projected_edges

      def validate_external_filters(values, name, allow_empty:)
        valid = values.is_a?(Array) && values.all?(Common::Filter)
        valid &&= !values.empty? unless allow_empty
        return if valid

        requirement = if allow_empty
                        'an Array of Filter values'
                      else
                        'a non-empty Array of Filter values'
                      end
        raise ArgumentError, "#{name} must be #{requirement}"
      end
      private_class_method :validate_external_filters
    end
  end
end
