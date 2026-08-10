# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../../common/projection/project_edges'
require_relative '../../extraction/extract_graph'
require_relative '../assertion/contain_dependency'

module ArchUnit
  module Slices
    module FluentApi
      # Executable `slices should not contain dependency` rule.
      class ForbiddenSliceDependencyCondition
        include Common::FluentApi::Checkable

        attr_reader :scope, :project_locator, :projection, :source_slice, :target_slice

        def initialize(scope, source_slice:, target_slice:)
          unless scope.is_a?(SliceScopeBuilder)
            raise ArgumentError, 'scope must be a SliceScopeBuilder'
          end

          @scope = scope
          @project_locator = scope.project_locator
          @projection = scope.projection
          @source_slice = immutable_slice_name(source_slice, :source_slice)
          @target_slice = immutable_slice_name(target_slice, :target_slice)
          freeze
        end

        def negated?
          true
        end

        private

        def perform_check(options)
          graph = ArchUnit::Extraction.extract_graph(project_locator, options:)
          empty_test = empty_test_violation(
            projection.slice_labels(graph), filters: [], negated: true, options:
          )
          return empty_test if empty_test

          edges = Common::Projection.project_edges(graph, projection)
          Assertion.gather_forbidden_slice_dependency_violations(
            edges, source_slice, target_slice
          )
        end

        def immutable_slice_name(value, attribute)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, "#{attribute} must be a non-empty String"
        end
      end
    end
  end
end
