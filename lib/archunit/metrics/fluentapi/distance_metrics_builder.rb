# frozen_string_literal: true

require_relative '../calculation/distance'
require_relative 'metric_selection'
require_relative 'zone_condition'

module ArchUnit
  module Metrics
    module FluentApi
      # Fluent distance metric names and architectural zone guards.
      class DistanceMetricsBuilder
        attr_reader :scope

        def initialize(scope)
          raise ArgumentError, 'scope must be a MetricsBuilder' unless scope.is_a?(MetricsBuilder)

          @scope = scope
          freeze
        end

        Calculation::Distance::CALCULATIONS.each_key do |name|
          define_method(name) do
            MetricSelection.new(scope:, metric: Calculation::Distance.public_send(name))
          end
        end

        def not_in_zone_of_pain
          ZoneCondition.new(scope:, zone: :pain)
        end

        def not_in_zone_of_uselessness
          ZoneCondition.new(scope:, zone: :uselessness)
        end
      end
    end
  end
end
