# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../calculation/metric'
require_relative '../calculation/numeric_value'

module ArchUnit
  module Metrics
    # Pure arbitrary metric predicates and structured violation data.
    module Assertion
      # One built-in metric value that did not satisfy a user predicate.
      class MetricPredicateViolation < Common::Assertion::Violation
        attr_reader :subject, :metric_name, :value

        def initialize(subject:, metric_name:, value:)
          unless subject.respond_to?(:identifier)
            raise ArgumentError, 'subject must expose an identifier'
          end

          @subject = subject
          @metric_name = immutable_metric_name(metric_name)
          @value = Calculation::NumericValue.validate(value)
          super()
        end

        def identifier
          subject.identifier
        end

        private

        def immutable_metric_name(value)
          return value if value.is_a?(Symbol)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'metric_name must be a Symbol or non-empty String'
        end
      end

      module_function

      def gather_metric_predicate_violations(subjects, metric, predicate)
        validate_predicate_assertion(subjects, metric, predicate)
        subjects.filter_map do |subject|
          value = metric.calculate(subject)
          next if predicate.call(value, subject)

          MetricPredicateViolation.new(subject:, metric_name: metric.name, value:)
        end
      end

      def validate_predicate_assertion(subjects, metric, predicate)
        raise ArgumentError, 'metric must be a Metric' unless metric.is_a?(Calculation::Metric)

        unless subjects.is_a?(Array) && subjects.all?(metric.subject_type)
          type_name = metric.subject_type.name.split('::').last
          raise ArgumentError, "subjects must be an Array of #{type_name} values"
        end
        return if predicate.respond_to?(:call)

        raise ArgumentError, 'predicate must respond to call'
      end
      private_class_method :validate_predicate_assertion
    end
  end
end
