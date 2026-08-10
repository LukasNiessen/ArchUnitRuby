# frozen_string_literal: true

require_relative '../extraction/metric_info'
require_relative 'metric'

module ArchUnit
  module Metrics
    module Calculation
      # Pure count metrics over extracted Ruby class and file information.
      module Count
        CLASS_METRICS = {
          method_count: ->(class_info) { class_info.methods.length },
          field_count: ->(class_info) { class_info.fields.length }
        }.freeze
        FILE_METRICS = {
          lines_of_code: :lines_of_code.to_proc,
          statements: :statement_count.to_proc,
          imports: :import_count.to_proc,
          classes: :class_count.to_proc,
          functions: :function_count.to_proc
        }.freeze

        CLASS_METRICS.each do |name, calculation|
          define_singleton_method(name) do
            Metric.new(
              name:,
              subject_type: Metrics::Extraction::ClassInfo,
              calculation:
            )
          end
        end

        FILE_METRICS.each do |name, calculation|
          define_singleton_method(name) do
            Metric.new(
              name:,
              subject_type: Metrics::Extraction::FileInfo,
              calculation:
            )
          end
        end
      end
    end
  end
end
