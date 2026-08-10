# frozen_string_literal: true

require_relative '../extraction/metric_info'
require_relative 'metric'

module ArchUnit
  module Metrics
    module Calculation
      # Pure lack-of-cohesion calculations over extracted method/field relationships.
      module LCOM
        CALCULATIONS = {
          lcom96a: ->(class_info) { normalized_method_field_distance(class_info) },
          lcom96b: ->(class_info) { method_field_density_complement(class_info) },
          lcom1: ->(class_info) { pair_difference(class_info) },
          lcom2: ->(class_info) { method_field_density_complement(class_info) },
          lcom3: ->(class_info) { normalized_method_field_distance(class_info) },
          lcom4: ->(class_info) { connected_components(class_info) },
          lcom5: ->(class_info) { normalized_method_field_distance(class_info) },
          lcom_star: ->(class_info) { normalized_method_field_distance(class_info) }
        }.freeze

        CALCULATIONS.each do |name, calculation|
          define_singleton_method(name) do
            Metric.new(
              name:,
              subject_type: Metrics::Extraction::ClassInfo,
              calculation:
            )
          end
        end

        module_function

        def normalized_method_field_distance(class_info)
          method_count = class_info.methods.length
          field_count = class_info.fields.length
          return 0.0 if method_count <= 1 || field_count.zero?

          average_accesses = field_access_count(class_info).fdiv(field_count)
          (method_count - average_accesses).fdiv(method_count - 1)
        end
        private_class_method :normalized_method_field_distance

        def method_field_density_complement(class_info)
          method_count = class_info.methods.length
          field_count = class_info.fields.length
          return 0.0 if method_count <= 1 || field_count.zero?

          1.0 - field_access_count(class_info).fdiv(method_count * field_count)
        end
        private_class_method :method_field_density_complement

        def field_access_count(class_info)
          class_info.fields.sum { |field| field.accessed_by.length }
        end
        private_class_method :field_access_count

        def pair_difference(class_info)
          sharing, non_sharing = method_pairs(class_info).partition do |left, right|
            fields_overlap?(left, right)
          end
          [non_sharing.length - sharing.length, 0].max
        end
        private_class_method :pair_difference

        def method_pairs(class_info)
          class_info.methods.combination(2).to_a
        end
        private_class_method :method_pairs

        def fields_overlap?(left, right)
          left.accessed_fields.intersect?(right.accessed_fields)
        end
        private_class_method :fields_overlap?

        def connected_components(class_info)
          methods = class_info.methods
          return 0 if methods.empty?

          remaining = methods.dup
          components = 0
          until remaining.empty?
            components += 1
            remove_component(remaining)
          end
          components
        end
        private_class_method :connected_components

        def remove_component(remaining)
          pending = [remaining.first]
          until pending.empty?
            method = pending.pop
            next unless remaining.delete(method)

            pending.concat(remaining.select { |candidate| fields_overlap?(method, candidate) })
          end
        end
        private_class_method :remove_component
      end
    end
  end
end
