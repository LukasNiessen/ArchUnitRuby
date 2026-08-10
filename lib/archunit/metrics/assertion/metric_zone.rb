# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../calculation/distance'
require_relative '../extraction/metric_info'

module ArchUnit
  module Metrics
    # Pure assertions and structured metric violation data.
    module Assertion
      # A file whose abstractness/instability point falls in a discouraged zone.
      class MetricZoneViolation < Common::Assertion::Violation
        ZONES = %i[pain uselessness].freeze

        attr_reader :distance_info, :zone

        def initialize(distance_info:, zone:)
          unless distance_info.is_a?(Extraction::DistanceInfo)
            raise ArgumentError, 'distance_info must be a DistanceInfo value'
          end
          unless ZONES.include?(zone)
            raise ArgumentError, "unknown architectural zone: #{zone.inspect}"
          end

          @distance_info = distance_info
          @zone = zone
          super()
        end

        def abstractness
          Calculation::Distance.abstractness.calculate(distance_info)
        end

        def instability
          Calculation::Distance.instability.calculate(distance_info)
        end
      end

      module_function

      def gather_metric_zone_violations(distance_infos, zone)
        unless distance_infos.is_a?(Array) && distance_infos.all?(Extraction::DistanceInfo)
          raise ArgumentError, 'distance_infos must be an Array of DistanceInfo values'
        end
        unless MetricZoneViolation::ZONES.include?(zone)
          raise ArgumentError, "unknown architectural zone: #{zone.inspect}"
        end

        distance_infos.filter_map do |distance_info|
          next unless Calculation::Distance.in_zone?(distance_info, zone)

          MetricZoneViolation.new(distance_info:, zone:)
        end
      end
    end
  end
end
