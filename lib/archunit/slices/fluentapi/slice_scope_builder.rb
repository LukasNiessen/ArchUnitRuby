# frozen_string_literal: true

require_relative '../projection/slicing_projections'
require_relative 'negative_slice_condition_builder'
require_relative 'positive_slice_condition_builder'
require_relative '../uml/export_diagram'
require_relative '../../common/fluentapi/check_options'
require_relative '../../common/projection/project_edges'
require_relative '../../extraction/extract_graph'

module ArchUnit
  module Slices
    # Sentence-like builders for slice architecture rules.
    module FluentApi
      # Immutable scope describing how project files become named slices.
      class SliceScopeBuilder
        attr_reader :project_locator, :projection

        def initialize(project_locator: nil, projection: Projection.identity)
          @project_locator = immutable_project_locator(project_locator)
          @projection = projection_value(projection)
          freeze
        end

        def defined_by(pattern)
          copy(projection: Projection.slice_by_pattern(pattern))
        end

        def defined_by_regex(regexp)
          copy(projection: Projection.slice_by_regex(regexp))
        end

        def should_not
          NegativeSliceConditionBuilder.new(self)
        end

        def should
          PositiveSliceConditionBuilder.new(self)
        end

        def to_plantuml(options = nil)
          graph = extract_graph(options)
          edges = Common::Projection.project_edges(graph, projection)
          Uml::PlantUmlRenderer.render(edges, components: projection.slice_labels(graph))
        end

        def export_as_plantuml(output_path, options = nil)
          graph = extract_graph(options)
          edges = Common::Projection.project_edges(graph, projection)
          Uml::PlantUmlRenderer.export(
            edges, output_path, components: projection.slice_labels(graph)
          )
        end

        private

        def copy(projection: self.projection)
          self.class.new(project_locator:, projection:)
        end

        def extract_graph(options)
          options = Common::FluentApi::CheckOptions.resolve(options)
          ArchUnit::Extraction.extract_graph(project_locator, options:)
        end

        def immutable_project_locator(locator)
          return if locator.nil?

          locator = locator.to_path if locator.respond_to?(:to_path)
          return locator.dup.freeze if locator.is_a?(String) && !locator.empty?

          raise ArgumentError, 'project_locator must be a non-empty path or nil'
        end

        def projection_value(value)
          return value if value.is_a?(Projection::SliceProjection)

          raise ArgumentError, 'projection must be a SliceProjection'
        end
      end
    end
  end
end
