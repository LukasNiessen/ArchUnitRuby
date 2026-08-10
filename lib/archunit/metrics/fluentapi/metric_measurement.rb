# frozen_string_literal: true

module ArchUnit
  module Metrics
    module FluentApi
      # One calculated metric value and the extracted subject it describes.
      MetricMeasurement = Data.define(:subject, :metric_name, :value) do
        def initialize(subject:, metric_name:, value:)
          unless subject.respond_to?(:identifier)
            raise ArgumentError, 'subject must expose an identifier'
          end

          metric_name = immutable_metric_name(metric_name)
          raise ArgumentError, 'value must be Numeric' unless value.is_a?(Numeric)

          super
        end

        def identifier
          subject.identifier
        end

        private

        def immutable_metric_name(value)
          return value if value.is_a?(Symbol)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'metric_name must be a Symbol or non-empty String'
        end
      end
    end
  end
end
