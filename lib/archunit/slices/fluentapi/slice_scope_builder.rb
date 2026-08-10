# frozen_string_literal: true

require_relative '../projection/slicing_projections'
require_relative 'negative_slice_condition_builder'

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

        private

        def copy(projection: self.projection)
          self.class.new(project_locator:, projection:)
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
