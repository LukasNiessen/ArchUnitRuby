# frozen_string_literal: true

require_relative '../calculation/metric'
require_relative '../extraction/metric_info'
require_relative 'custom_metric_condition'
require_relative 'metric_selection'

module ArchUnit
  module Metrics
    module FluentApi
      # A user-defined class calculation that can be measured or asserted.
      class CustomMetricBuilder < MetricSelection
        def initialize(scope:, name:, description:, calculation:)
          unless name.is_a?(String) && !name.empty?
            raise ArgumentError, 'custom metric name must be a non-empty String'
          end

          metric = Calculation::Metric.new(
            name:, description:, subject_type: Extraction::ClassInfo, calculation:
          )
          super(scope:, metric:)
        end

        def should_satisfy(predicate)
          CustomMetricCondition.new(selection: self, predicate:)
        end
      end
    end
  end
end
