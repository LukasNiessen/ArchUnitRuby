# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../calculation/metric'
require_relative '../calculation/numeric_value'

module ArchUnit
  module Metrics
    # Pure metric threshold assertions and structured violation data.
    module Assertion
      # One metric value that did not meet its numeric threshold.
      class MetricThresholdViolation < Common::Assertion::Violation
        COMPARISONS = %i[below above equal below_or_equal above_or_equal].freeze

        attr_reader :subject, :metric_name, :value, :threshold, :comparison

        def initialize(subject:, metric_name:, value:, threshold:, comparison:)
          @subject = validated_subject(subject)
          @metric_name = immutable_metric_name(metric_name)
          @value = Calculation::NumericValue.validate(value)
          @threshold = Calculation::NumericValue.validate(threshold, attribute: 'threshold')
          @comparison = validated_comparison(comparison)
          super()
        end

        def identifier
          subject.identifier
        end

        private

        def validated_subject(value)
          return value if value.respond_to?(:identifier)

          raise ArgumentError, 'subject must expose an identifier'
        end

        def validated_comparison(value)
          return value if COMPARISONS.include?(value)

          raise ArgumentError, "unknown metric comparison: #{value.inspect}"
        end

        def immutable_metric_name(value)
          return value if value.is_a?(Symbol)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'metric_name must be a Symbol or non-empty String'
        end
      end

      module_function

      def gather_metric_threshold_violations(subjects, metric, comparison, threshold)
        validate_metric_assertion(subjects, metric)
        threshold = validate_threshold(comparison, threshold)

        subjects.filter_map do |subject|
          value = metric.calculate(subject)
          next if threshold_satisfied?(value, comparison, threshold)

          MetricThresholdViolation.new(
            subject:, metric_name: metric.name, value:, threshold:, comparison:
          )
        end
      end

      def validate_threshold(comparison, threshold)
        unless MetricThresholdViolation::COMPARISONS.include?(comparison)
          raise ArgumentError, "unknown metric comparison: #{comparison.inspect}"
        end

        Calculation::NumericValue.validate(threshold, attribute: 'threshold')
      end
      private_class_method :validate_threshold

      def threshold_satisfied?(value, comparison, threshold)
        case comparison
        when :below then value < threshold
        when :above then value > threshold
        when :equal then value == threshold
        when :below_or_equal then value <= threshold
        when :above_or_equal then value >= threshold
        end
      end
      private_class_method :threshold_satisfied?

      def validate_metric_assertion(subjects, metric)
        raise ArgumentError, 'metric must be a Metric' unless metric.is_a?(Calculation::Metric)

        return if subjects.is_a?(Array) && subjects.all?(metric.subject_type)

        type_name = metric.subject_type.name.split('::').last
        raise ArgumentError, "subjects must be an Array of #{type_name} values"
      end
      private_class_method :validate_metric_assertion
    end
  end
end
