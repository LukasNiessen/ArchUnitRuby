# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../calculation/metric'
require_relative '../extraction/metric_info'

module ArchUnit
  module Metrics
    # Pure assertions and structured custom metric violation data.
    module Assertion
      # A class whose calculated custom value did not satisfy the user's predicate.
      class CustomMetricViolation < Common::Assertion::Violation
        attr_reader :class_info, :metric_name, :description, :value

        def initialize(class_info:, metric_name:, description:, value:)
          @class_info = class_info_value(class_info)
          @metric_name = immutable_string(metric_name, :metric_name)
          @description = immutable_string(description, :description)
          @value = numeric_value(value)
          super()
        end

        private

        def class_info_value(value)
          return value if value.is_a?(Extraction::ClassInfo)

          raise ArgumentError, 'class_info must be a ClassInfo value'
        end

        def immutable_string(value, attribute)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, "#{attribute} must be a non-empty String"
        end

        def numeric_value(value)
          return value if value.is_a?(Numeric)

          raise ArgumentError, 'value must be Numeric'
        end
      end

      module_function

      def gather_custom_metric_violations(class_infos, metric, predicate)
        validate_custom_metric_arguments(class_infos, metric, predicate)
        class_infos.filter_map do |class_info|
          value = metric.calculate(class_info)
          next if predicate.call(value, class_info)

          CustomMetricViolation.new(
            class_info:, metric_name: metric.name,
            description: metric.description, value:
          )
        end
      end

      def validate_custom_metric_arguments(class_infos, metric, predicate)
        unless class_infos.is_a?(Array) && class_infos.all?(Extraction::ClassInfo)
          raise ArgumentError, 'class_infos must be an Array of ClassInfo values'
        end
        unless metric.is_a?(Calculation::Metric) && metric.name.is_a?(String) && metric.description
          raise ArgumentError, 'metric must be a described custom Metric'
        end
        return if predicate.respond_to?(:call)

        raise ArgumentError, 'predicate must respond to call'
      end
      private_class_method :validate_custom_metric_arguments
    end
  end
end
