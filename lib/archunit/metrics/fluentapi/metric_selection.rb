# frozen_string_literal: true

require_relative '../calculation/metric'
require_relative 'metric_measurement'

module ArchUnit
  module Metrics
    module FluentApi
      # Lazy selection of one metric over a metrics scope.
      class MetricSelection
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
      end
    end
  end
end
