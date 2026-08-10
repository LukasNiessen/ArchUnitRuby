# frozen_string_literal: true

require_relative '../extraction/metric_info'
require_relative 'metric'

module ArchUnit
  module Metrics
    module Calculation
      # Robert C. Martin's abstractness, instability, distance, and zone calculations.
      module Distance
        PAIN_LIMIT = 0.3
        USELESSNESS_LIMIT = 0.7
        SIZE_NORMALIZATION_LINES = 100.0
        MAXIMUM_SIZE_DISCOUNT = 0.5

        CALCULATIONS = {
          abstractness: ->(info) { abstractness_value(info) },
          instability: ->(info) { instability_value(info) },
          distance_from_main_sequence: ->(info) { distance_value(info) },
          coupling_factor: ->(info) { coupling_factor_value(info) },
          normalized_distance: ->(info) { normalized_distance_value(info) }
        }.freeze

        CALCULATIONS.each do |name, calculation|
          define_singleton_method(name) do
            Metric.new(
              name:, subject_type: Metrics::Extraction::DistanceInfo, calculation:
            )
          end
        end

        module_function

        def in_zone?(distance_info, zone)
          abstractness = abstractness_value(distance_info)
          instability = instability_value(distance_info)
          case zone
          when :pain
            abstractness < PAIN_LIMIT && instability < PAIN_LIMIT
          when :uselessness
            abstractness > USELESSNESS_LIMIT && instability > USELESSNESS_LIMIT
          else
            raise ArgumentError, "unknown architectural zone: #{zone.inspect}"
          end
        end

        def abstractness_value(info)
          return 0.0 if info.type_count.zero?

          info.abstract_type_count.fdiv(info.type_count)
        end
        private_class_method :abstractness_value

        def instability_value(info)
          total = info.afferent_coupling + info.efferent_coupling
          return 0.0 if total.zero?

          info.efferent_coupling.fdiv(total)
        end
        private_class_method :instability_value

        def distance_value(info)
          (abstractness_value(info) + instability_value(info) - 1.0).abs
        end
        private_class_method :distance_value

        def coupling_factor_value(info)
          possible = 2 * (info.project_file_count - 1)
          return 0.0 if possible.zero?

          (info.afferent_coupling + info.efferent_coupling).fdiv(possible)
        end
        private_class_method :coupling_factor_value

        def normalized_distance_value(info)
          size_ratio = [info.lines_of_code.fdiv(SIZE_NORMALIZATION_LINES), 1.0].min
          discount = size_ratio * MAXIMUM_SIZE_DISCOUNT
          distance_value(info) * (1.0 - discount)
        end
        private_class_method :normalized_distance_value
      end
    end
  end
end
