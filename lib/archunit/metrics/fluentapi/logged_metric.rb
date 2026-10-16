# frozen_string_literal: true

require_relative '../../common/logging/inspection'

module ArchUnit
  module Metrics
    module FluentApi
      # Observes the existing calculation once, including values that pass the rule.
      module LoggedMetric
        def self.wrap(metric)
          logger = Common::Logging::Inspection.logger
          return metric unless logger&.debug?

          metric.with(calculation: lambda do |subject|
            value = metric.calculate(subject)
            logger.log_metric(name: metric.name, value:, subject: subject.identifier)
            value
          end)
        end
      end
    end
  end
end
