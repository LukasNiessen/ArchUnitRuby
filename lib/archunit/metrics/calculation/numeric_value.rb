# frozen_string_literal: true

module ArchUnit
  module Metrics
    module Calculation
      # Validation shared by metric calculations, thresholds, and measurements.
      module NumericValue
        module_function

        def validate(value, attribute: 'value', error_class: ArgumentError)
          return value if finite_real_number?(value)

          raise error_class, "#{attribute} must be a finite real Numeric value"
        end

        def finite_real_number?(value)
          return false unless value.is_a?(Numeric) && value.real?
          return value.finite? if value.respond_to?(:finite?)

          true
        end
      end
    end
  end
end
