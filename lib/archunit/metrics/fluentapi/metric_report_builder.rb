# frozen_string_literal: true

require_relative '../reporting/metrics_export_options'
require_relative '../reporting/metrics_exporter'

module ArchUnit
  module Metrics
    module FluentApi
      # Shared HTML export terminal for one family of scoped metrics.
      module MetricReportBuilder
        def export_as_html(output_path, options = nil)
          options = Reporting::MetricsExportOptions.resolve(options).with(output_path:)
          Reporting::MetricsExporter.export_as_html(metric_report_data, options)
          nil
        end

        private

        def metric_report_data
          report_metrics.group_by(&:subject_type).each_with_object({}) do |(type, metrics), data|
            subjects = scope.__send__(:subjects_for, type)
            metrics.each { |metric| add_metric_values(data, subjects, metric) }
          end.freeze
        end

        def add_metric_values(data, subjects, metric)
          subjects.each do |subject|
            data["#{metric.name} [#{subject.identifier}]"] = metric.calculate(subject)
          end
        end
      end
    end
  end
end
