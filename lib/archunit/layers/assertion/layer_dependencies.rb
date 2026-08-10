# frozen_string_literal: true

require_relative '../../common/projection/projected_edge'
require_relative 'layer_definition'
require_relative 'layer_dependency_violation'

module ArchUnit
  module Layers
    # Pure assertions over dependencies between named architectural layers.
    module Assertion
      module_function

      def gather_layer_dependency_violations(
        edges, layers, allowed_dependencies, forbidden_dependencies
      )
        validate_arguments(edges, layers, allowed_dependencies, forbidden_dependencies)

        edges.filter_map do |edge|
          dependency_violation(edge, layers, allowed_dependencies, forbidden_dependencies)
        end
      end

      def dependency_violation(edge, layers, allowed_dependencies, forbidden_dependencies)
        source_layer = find_layer(edge.source_label, layers)
        target_layer = find_layer(edge.target_label, layers)
        return unless source_layer && target_layer
        return if source_layer.name == target_layer.name

        rule = violated_rule(
          source_layer.name, target_layer.name, allowed_dependencies, forbidden_dependencies
        )
        return unless rule

        build_violation(edge, source_layer, target_layer, rule)
      end
      private_class_method :dependency_violation

      def build_violation(edge, source_layer, target_layer, rule)
        LayerDependencyViolation.new(
          dependency: edge, source_layer: source_layer.name, target_layer: target_layer.name, rule:
        )
      end
      private_class_method :build_violation

      def violated_rule(source, target, allowed_dependencies, forbidden_dependencies)
        forbidden_targets = forbidden_dependencies.fetch(source, [])
        return :may_not_depend_on_layers if forbidden_targets.include?(target)
        return unless allowed_dependencies.key?(source)
        return if allowed_dependencies.fetch(source).include?(target)

        :may_only_depend_on_layers
      end
      private_class_method :violated_rule

      def find_layer(file_path, layers)
        layers.find { |layer| layer.matches?(file_path) }
      end
      private_class_method :find_layer

      def validate_arguments(edges, layers, allowed_dependencies, forbidden_dependencies)
        unless edges.is_a?(Array) && edges.all?(Common::Projection::ProjectedEdge)
          raise ArgumentError, 'edges must be an Array of ProjectedEdge values'
        end
        unless layers.is_a?(Array) && layers.all?(LayerDefinition)
          raise ArgumentError, 'layers must be an Array of LayerDefinition values'
        end

        validate_dependency_map(allowed_dependencies, :allowed_dependencies)
        validate_dependency_map(forbidden_dependencies, :forbidden_dependencies)
      end
      private_class_method :validate_arguments

      def validate_dependency_map(value, attribute)
        valid = value.is_a?(Hash) && value.all? do |source, targets|
          valid_layer_name?(source) && targets.is_a?(Array) && targets.all? do |target|
            valid_layer_name?(target)
          end
        end
        return if valid

        raise ArgumentError, "#{attribute} must map layer names to Arrays of layer names"
      end
      private_class_method :validate_dependency_map

      def valid_layer_name?(value)
        value.is_a?(String) && !value.strip.empty?
      end
      private_class_method :valid_layer_name?
    end
  end
end
