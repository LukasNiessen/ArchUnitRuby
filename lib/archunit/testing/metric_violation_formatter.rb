# frozen_string_literal: true

module ArchUnit
  module Testing
    # Formatting helpers for structured metric violations.
    module MetricViolationFormatter
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
    end
  end
end
