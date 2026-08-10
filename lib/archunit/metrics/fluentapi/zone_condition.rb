# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../assertion/metric_zone'

module ArchUnit
  module Metrics
    module FluentApi
      # Executable guard that rejects files in one architectural distance zone.
      class ZoneCondition
        include Common::FluentApi::Checkable

        attr_reader :scope, :zone

        def initialize(scope:, zone:)
          raise ArgumentError, 'scope must be a MetricsBuilder' unless scope.is_a?(MetricsBuilder)
          unless Assertion::MetricZoneViolation::ZONES.include?(zone)
            raise ArgumentError, "unknown architectural zone: #{zone.inspect}"
          end

          @scope = scope
          @zone = zone
          freeze
        end

        private

        def perform_check(options)
          distance_infos = scope.__send__(:distance_subjects, options:)
          empty_test = empty_test_violation(
            distance_infos, filters: scope.filters, negated: false, options:
          )
          return empty_test if empty_test

          Assertion.gather_metric_zone_violations(distance_infos, zone)
        end
      end
    end
  end
end
