# frozen_string_literal: true

module ArchUnit
  module Testing
    # Formatting helpers for structured metric violations.
    module MetricViolationFormatter
      FORMATTERS = {
        Metrics::Assertion::CustomMetricViolation => :custom_metric,
        Metrics::Assertion::MetricPredicateViolation => :metric_predicate,
        Metrics::Assertion::MetricThresholdViolation => :metric_threshold,
        Metrics::Assertion::MetricZoneViolation => :metric_zone
      }.freeze

      private

      def custom_metric(violation)
        TestViolation.new(
          message: 'Custom metric violation',
          details: "Class '#{violation.class_info.name}' in '#{violation.class_info.file_path}' " \
                   "has #{violation.metric_name}=#{violation.value.inspect}; " \
                   "#{violation.description}."
        )
      end

      def metric_zone(violation)
        zone = violation.zone == :pain ? 'pain' : 'uselessness'
        TestViolation.new(
          message: 'Metric zone violation',
          details: "File '#{violation.distance_info.path}' is in the zone of #{zone} " \
                   "(abstractness=#{format('%.2f', violation.abstractness)}, " \
                   "instability=#{format('%.2f', violation.instability)})."
        )
      end

      def metric_threshold(violation)
        expectation = {
          below: 'below', above: 'above', equal: 'equal to',
          below_or_equal: 'below or equal to', above_or_equal: 'above or equal to'
        }.fetch(violation.comparison)
        TestViolation.new(
          message: 'Metric threshold violation',
          details: "Metric subject '#{violation.identifier}' has " \
                   "#{violation.metric_name}=#{violation.value.inspect}; " \
                   "expected #{expectation} #{violation.threshold.inspect}."
        )
      end

      def metric_predicate(violation)
        TestViolation.new(
          message: 'Metric predicate violation',
          details: "Metric subject '#{violation.identifier}' has " \
                   "#{violation.metric_name}=#{violation.value.inspect}; " \
                   'the should_satisfy predicate returned false.'
        )
      end
    end
  end
end
