# frozen_string_literal: true

require_relative 'metrics_builder'

# Public ArchUnitRuby API.
module ArchUnit
  module Metrics
    # Public entry point for numeric Ruby source metrics.
    module FluentApi
      module_function

      def metrics(project_locator = nil)
        MetricsBuilder.new(project_locator:)
      end
    end
  end

  def self.metrics(project_locator = nil)
    Metrics::FluentApi.metrics(project_locator)
  end
end
