# frozen_string_literal: true

require_relative 'metrics_builder'

# Public ArchUnitRuby API.
module ArchUnit
  module Metrics
    # Public entry point for numeric Ruby source metrics.
    module FluentApi
      module_function

      # Starts an immutable source-metrics scope.
      # @return [MetricsBuilder]
      def metrics(project_locator = nil)
        MetricsBuilder.new(project_locator:)
      end
    end
  end

  # Starts an immutable source-metrics scope.
  # @param project_locator [String, Pathname, nil] project directory, Gemfile, or gemspec
  # @return [Metrics::FluentApi::MetricsBuilder]
  def self.metrics(project_locator = nil)
    Metrics::FluentApi.metrics(project_locator)
  end
end
