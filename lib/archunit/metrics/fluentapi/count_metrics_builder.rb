# frozen_string_literal: true

require_relative '../calculation/count'
require_relative 'metric_selection'

module ArchUnit
  module Metrics
    module FluentApi
      # Fluent count-metric names for one immutable metrics scope.
      class CountMetricsBuilder
        attr_reader :scope

        def initialize(scope)
          raise ArgumentError, 'scope must be a MetricsBuilder' unless scope.is_a?(MetricsBuilder)

          @scope = scope
          freeze
        end

        Calculation::Count::CLASS_METRICS.each_key do |name|
          define_method(name) do
            MetricSelection.new(scope:, metric: Calculation::Count.public_send(name))
          end
        end

        Calculation::Count::FILE_METRICS.each_key do |name|
          define_method(name) do
            MetricSelection.new(scope:, metric: Calculation::Count.public_send(name))
          end
        end
      end
    end
  end
end
