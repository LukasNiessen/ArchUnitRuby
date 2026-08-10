# frozen_string_literal: true

require_relative 'forbidden_slice_dependency_condition'

module ArchUnit
  module Slices
    module FluentApi
      # Immutable negated mood for forbidden slice dependencies.
      class NegativeSliceConditionBuilder
        attr_reader :scope

        def initialize(scope)
          unless scope.is_a?(SliceScopeBuilder)
            raise ArgumentError, 'scope must be a SliceScopeBuilder'
          end

          @scope = scope
          freeze
        end

        def contain_dependency(source_slice, target_slice)
          ForbiddenSliceDependencyCondition.new(scope, source_slice:, target_slice:)
        end
      end
    end
  end
end
