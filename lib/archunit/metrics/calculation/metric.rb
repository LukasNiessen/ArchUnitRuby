# frozen_string_literal: true

module ArchUnit
  module Metrics
    module Calculation
      # Immutable named calculation over one extracted subject type.
      Metric = Data.define(:name, :subject_type, :calculation) do
        def initialize(name:, subject_type:, calculation:)
          raise ArgumentError, 'name must be a Symbol' unless name.is_a?(Symbol)
          raise ArgumentError, 'subject_type must be a Class' unless subject_type.is_a?(Class)
          unless calculation.respond_to?(:call)
            raise ArgumentError, 'calculation must respond to call'
          end

          calculation = calculation.dup.freeze
          super
        end

        def calculate(subject)
          unless subject.is_a?(subject_type)
            raise ArgumentError, "subject must be a #{subject_type.name.split('::').last}"
          end

          value = calculation.call(subject)
          return value if value.is_a?(Numeric)

          raise TypeError, 'metric calculations must return a Numeric value'
        end
      end
    end
  end
end
