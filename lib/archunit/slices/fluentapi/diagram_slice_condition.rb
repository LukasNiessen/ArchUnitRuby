# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../../common/projection/project_edges'
require_relative '../../extraction/extract_graph'
require_relative '../assertion/adhere_to_diagram'
require_relative '../uml/parse_diagram'

module ArchUnit
  module Slices
    module FluentApi
      # Executable `slices should adhere to diagram` rule.
      class DiagramSliceCondition
        include Common::FluentApi::Checkable

        attr_reader :scope, :project_locator, :projection, :diagram_source, :options

        def initialize(scope, diagram_source, options:)
          @scope = scope_value(scope)
          @project_locator = scope.project_locator
          @projection = scope.projection
          @diagram_source = diagram_source_value(diagram_source)
          @options = options_value(options)
          freeze
        end

        def negated?
          false
        end

        private

        def perform_check(check_options)
          graph = ArchUnit::Extraction.extract_graph(project_locator, options: check_options)
          empty_test = empty_test_violation(
            projection.slice_labels(graph), filters: [], negated: false, options: check_options
          )
          return empty_test if empty_test

          diagram = Uml::PlantUmlParser.parse(diagram_source.read)
          edges = Common::Projection.project_edges(graph, projection)
          Assertion.gather_diagram_adherence_violations(edges, diagram, options)
        end

        def scope_value(value)
          return value if value.is_a?(SliceScopeBuilder)

          raise ArgumentError, 'scope must be a SliceScopeBuilder'
        end

        def diagram_source_value(value)
          return value if value.is_a?(DiagramSource)

          raise ArgumentError, 'diagram_source must be a DiagramSource'
        end

        def options_value(value)
          return value if value.is_a?(Assertion::DiagramAdherenceOptions)

          raise ArgumentError, 'options must be DiagramAdherenceOptions'
        end
      end
    end
  end
end
