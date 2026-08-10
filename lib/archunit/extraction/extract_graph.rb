# frozen_string_literal: true

require 'pathname'
require_relative '../common/extraction/edge'
require_relative '../common/extraction/graph'
require_relative 'enumerate_source_files'
require_relative 'extract_dependencies'
require_relative 'locate_project'

module ArchUnit
  # Assembles the normalized dependency graph for a Ruby project.
  module Extraction
    module_function

    def extract_graph(locator = nil, working_directory: Dir.pwd)
      root = Pathname.new(locate_project(locator, working_directory:))
      source_files = enumerate_source_files(root)
      edges = self_edges(source_files) + extract_dependencies_from(root, source_files)

      Common::Extraction::Graph.new(merge_parallel_edges(edges))
    end

    def self_edges(source_files)
      source_files.map do |source|
        Common::Extraction::Edge.new(source: source, target: source, external: false)
      end
    end
    private_class_method :self_edges

    def merge_parallel_edges(edges)
      edges.group_by { |edge| [edge.source, edge.target] }.values.map do |parallel_edges|
        first = parallel_edges.first
        Common::Extraction::Edge.new(
          source: first.source,
          target: first.target,
          external: first.external,
          import_kinds: parallel_edges.flat_map(&:import_kinds)
        )
      end
    end
    private_class_method :merge_parallel_edges
  end
end
