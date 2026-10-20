# frozen_string_literal: true

require_relative 'project_graph_builder'

# Public ArchUnitRuby entry points for dependency graph reports.
module ArchUnit
  module GraphReporting
    # Sentence-like entry points and builders for graph reporting.
    module FluentApi
      module_function

      # Starts an immutable dependency-graph report.
      # @return [ProjectGraphBuilder]
      def project_graph(project_locator = nil)
        ProjectGraphBuilder.new(project_locator:)
      end

      class << self
        alias dependency_graph project_graph
      end
    end
  end

  # Starts an immutable dependency-graph report.
  # @param project_locator [String, Pathname, nil] project directory, Gemfile, or gemspec
  # @return [GraphReporting::FluentApi::ProjectGraphBuilder]
  def self.project_graph(project_locator = nil)
    GraphReporting::FluentApi.project_graph(project_locator)
  end

  class << self
    alias dependency_graph project_graph
  end
end
