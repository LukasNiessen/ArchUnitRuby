# frozen_string_literal: true

require_relative '../../common/projection/projected_edge'
require_relative 'slice_dependency_violation'

module ArchUnit
  module Slices
    # Pure assertions over projected slice dependencies.
    module Assertion
      module_function

      def gather_forbidden_slice_dependency_violations(edges, source_slice, target_slice)
        validate_edges(edges)
        source_slice = validated_slice_name(source_slice, :source_slice)
        target_slice = validated_slice_name(target_slice, :target_slice)

        edges.filter_map do |edge|
          next unless edge.source_label == source_slice && edge.target_label == target_slice

          SliceDependencyViolation.new(
            dependency: edge, source_slice:, target_slice:,
            rule: :contain_dependency, is_negated: true
          )
        end
      end

      def validate_edges(value)
        return if value.is_a?(Array) && value.all?(Common::Projection::ProjectedEdge)

        raise ArgumentError, 'edges must be an Array of ProjectedEdge values'
      end
      private_class_method :validate_edges

      def validated_slice_name(value, attribute)
        return value if value.is_a?(String) && !value.strip.empty?

        raise ArgumentError, "#{attribute} must be a non-empty String"
      end
      private_class_method :validated_slice_name
    end
  end
end
