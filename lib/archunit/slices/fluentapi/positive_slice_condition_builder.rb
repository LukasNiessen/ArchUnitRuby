# frozen_string_literal: true

require_relative '../assertion/diagram_adherence_options'
require_relative 'diagram_slice_condition'
require_relative 'diagram_source'

module ArchUnit
  module Slices
    module FluentApi
      # Immutable positive mood and optional modifiers for diagram adherence.
      class PositiveSliceConditionBuilder
        attr_reader :scope, :options

        def initialize(scope, options: Assertion::DiagramAdherenceOptions.new)
          unless scope.is_a?(SliceScopeBuilder)
            raise ArgumentError, 'scope must be a SliceScopeBuilder'
          end
          unless options.is_a?(Assertion::DiagramAdherenceOptions)
            raise ArgumentError, 'options must be DiagramAdherenceOptions'
          end

          @scope = scope
          @options = options
          freeze
        end

        def ignoring_orphan_slices
          copy(options.with(ignore_orphan_slices: true))
        end

        def ignoring_external_slices
          copy(options.with(ignore_external_slices: true))
        end

        def adhere_to_diagram(text)
          DiagramSliceCondition.new(scope, DiagramSource.inline(text), options:)
        end

        def adhere_to_diagram_in_file(path)
          DiagramSliceCondition.new(scope, DiagramSource.file(path), options:)
        end

        private

        def copy(new_options)
          self.class.new(scope, options: new_options)
        end
      end
    end
  end
end
