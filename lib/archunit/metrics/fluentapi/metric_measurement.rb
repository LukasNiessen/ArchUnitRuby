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
          raise ArgumentError, 'metric_name must be a Symbol' unless metric_name.is_a?(Symbol)
          raise ArgumentError, 'value must be Numeric' unless value.is_a?(Numeric)

          super
        end

        def identifier
          subject.identifier
        end
      end
    end
  end
end
