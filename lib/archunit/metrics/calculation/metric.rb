# frozen_string_literal: true

require_relative 'numeric_value'

module ArchUnit
  module Metrics
    module Calculation
      # Immutable named calculation over one extracted subject type.
      Metric = Data.define(:name, :subject_type, :calculation, :description) do
        def initialize(name:, subject_type:, calculation:, description: nil)
          name = immutable_name(name)
          raise ArgumentError, 'subject_type must be a Class' unless subject_type.is_a?(Class)
          unless calculation.respond_to?(:call)
            raise ArgumentError, 'calculation must respond to call'
          end

          calculation = calculation.dup.freeze
          description = immutable_description(description)
          super
        end

        def calculate(subject)
          unless subject.is_a?(subject_type)
            raise ArgumentError, "subject must be a #{subject_type.name.split('::').last}"
          end

          NumericValue.validate(
            calculation.call(subject),
            attribute: 'metric calculations',
            error_class: TypeError
          )
        end

        private

        def immutable_name(value)
          return value if value.is_a?(Symbol)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'name must be a Symbol or non-empty String'
        end

        def immutable_description(value)
          return if value.nil?
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'description must be a non-empty String or nil'
        end
      end
    end
  end
end
