# frozen_string_literal: true

require_relative '../calculation/metric'
require_relative 'metric_measurement'
require_relative 'metric_predicate_condition'
require_relative 'metric_threshold_condition'

module ArchUnit
  module Metrics
    module FluentApi
      # Lazy selection of one metric over a metrics scope.
      class MetricSelection
        THRESHOLD_METHODS = {
          should_be_below: :below,
          should_be_above: :above,
          should_be: :equal,
          should_be_below_or_equal: :below_or_equal,
          should_be_above_or_equal: :above_or_equal
        }.freeze

        attr_reader :scope, :metric

        def initialize(scope:, metric:)
          raise ArgumentError, 'scope must be a MetricsBuilder' unless scope.is_a?(MetricsBuilder)
          raise ArgumentError, 'metric must be a Metric' unless metric.is_a?(Calculation::Metric)

          @scope = scope
          @metric = metric
          freeze
        end

        def measure
          scope.__send__(:subjects_for, metric.subject_type).map do |subject|
            MetricMeasurement.new(
              subject:,
              metric_name: metric.name,
              value: metric.calculate(subject)
            )
          end.freeze
        end

        THRESHOLD_METHODS.each do |method_name, comparison|
          define_method(method_name) do |threshold|
            MetricThresholdCondition.new(selection: self, comparison:, threshold:)
          end
        end

        def should_satisfy(predicate)
          MetricPredicateCondition.new(selection: self, predicate:)
        end
      end
    end
  end
end
