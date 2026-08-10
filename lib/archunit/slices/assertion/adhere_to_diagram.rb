# frozen_string_literal: true

require_relative '../../common/projection/projected_edge'
require_relative '../uml/plant_uml_diagram'
require_relative 'diagram_adherence_options'
require_relative 'slice_dependency_violation'

module ArchUnit
  module Slices
    # Pure assertions over projected slice dependencies.
    module Assertion
      module_function

      def gather_diagram_adherence_violations(edges, diagram, options = nil)
        validate_diagram_arguments(edges, diagram, options)
        options ||= DiagramAdherenceOptions.new

        edges.filter_map do |edge|
          next if ignored_diagram_edge?(edge, diagram, options)
          next if diagram.allows?(edge.source_label, edge.target_label)

          SliceDependencyViolation.new(
            dependency: edge, source_slice: edge.source_label,
            target_slice: edge.target_label, rule: :adhere_to_diagram, is_negated: false
          )
        end
      end

      def ignored_diagram_edge?(edge, diagram, options)
        return true if options.ignore_external_slices? && external_dependency?(edge)
        return false unless options.ignore_orphan_slices?

        !diagram.components.include?(edge.source_label) ||
          !diagram.components.include?(edge.target_label)
      end
      private_class_method :ignored_diagram_edge?

      def external_dependency?(edge)
        edge.cumulated_edges.any?(&:external)
      end
      private_class_method :external_dependency?

      def validate_diagram_arguments(edges, diagram, options)
        unless edges.is_a?(Array) && edges.all?(Common::Projection::ProjectedEdge)
          raise ArgumentError, 'edges must be an Array of ProjectedEdge values'
        end
        unless diagram.is_a?(Uml::PlantUmlDiagram)
          raise ArgumentError, 'diagram must be a PlantUmlDiagram'
        end
        return if options.nil? || options.is_a?(DiagramAdherenceOptions)

        raise ArgumentError, 'options must be DiagramAdherenceOptions or nil'
      end
      private_class_method :validate_diagram_arguments
    end
  end
end
