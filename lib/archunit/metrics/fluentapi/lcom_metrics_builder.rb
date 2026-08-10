# frozen_string_literal: true

require_relative '../calculation/lcom'
require_relative 'metric_report_builder'
require_relative 'metric_selection'

module ArchUnit
  module Metrics
    module FluentApi
      # Fluent LCOM metric names for one immutable metrics scope.
      class LCOMMetricsBuilder
        include MetricReportBuilder

        attr_reader :scope

        def initialize(scope)
          raise ArgumentError, 'scope must be a MetricsBuilder' unless scope.is_a?(MetricsBuilder)

          @scope = scope
          freeze
        end

        Calculation::LCOM::CALCULATIONS.each_key do |name|
          define_method(name) do
            MetricSelection.new(scope:, metric: Calculation::LCOM.public_send(name))
          end
        end

        private

        def report_metrics
          Calculation::LCOM::CALCULATIONS.each_key.map do |name|
            Calculation::LCOM.public_send(name)
          end
        end
      end
    end
  end
end
