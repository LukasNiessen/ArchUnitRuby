# frozen_string_literal: true

require_relative 'project_graph_builder'

# Public ArchUnitRuby entry points for dependency graph reports.
module ArchUnit
  module GraphReporting
    # Sentence-like entry points and builders for graph reporting.
    module FluentApi
      module_function

      def project_graph(project_locator = nil)
        ProjectGraphBuilder.new(project_locator:)
      end

      class << self
        alias dependency_graph project_graph
      end
    end
  end

  def self.project_graph(project_locator = nil)
    GraphReporting::FluentApi.project_graph(project_locator)
  end

  class << self
    alias dependency_graph project_graph
  end
end
