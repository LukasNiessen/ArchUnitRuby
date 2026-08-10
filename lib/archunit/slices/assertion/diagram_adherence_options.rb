# frozen_string_literal: true

module ArchUnit
  module Slices
    # Pure assertions over projected slice dependencies.
    module Assertion
      # Immutable modifiers controlling diagram coherence checks.
      DiagramAdherenceOptions = Data.define(:ignore_orphan_slices, :ignore_external_slices) do
        def initialize(ignore_orphan_slices: false, ignore_external_slices: false)
          validate_boolean(ignore_orphan_slices, :ignore_orphan_slices)
          validate_boolean(ignore_external_slices, :ignore_external_slices)
          super
        end

        def with(**overrides)
          self.class.new(**to_h, **overrides)
        end

        def ignore_orphan_slices?
          ignore_orphan_slices
        end

        def ignore_external_slices?
          ignore_external_slices
        end

        private

        def validate_boolean(value, attribute)
          return if [true, false].include?(value)

          raise ArgumentError, "#{attribute} must be true or false"
        end
      end
    end
  end
end
