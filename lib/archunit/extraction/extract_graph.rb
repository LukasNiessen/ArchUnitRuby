# frozen_string_literal: true

require 'pathname'
require_relative '../common/extraction/edge'
require_relative '../common/extraction/graph'
require_relative '../common/fluentapi/check_options'
require_relative 'enumerate_source_files'
require_relative 'extract_dependencies'
require_relative 'locate_project'

module ArchUnit
  # Assembles the normalized dependency graph for a Ruby project.
  module Extraction
    GRAPH_CACHE_MUTEX = Mutex.new
    GRAPH_INDEPENDENT_CHECK_OPTIONS = %i[allow_empty_tests logging clear_cache].freeze

    module_function

    def extract_graph(
      locator = nil, exclude_patterns: nil, options: nil, working_directory: Dir.pwd
    )
      options = Common::FluentApi::CheckOptions.resolve(options)
      root = Pathname.new(locate_project(locator, working_directory:))
      patterns = resolve_exclude_patterns(exclude_patterns)
      cache_key = graph_cache_key(root, exclude_patterns: patterns, options:)

      GRAPH_CACHE_MUTEX.synchronize do
        graph_cache.delete(cache_key) if options.clear_cache?
        graph_cache[cache_key] ||= extract_graph_uncached(root, patterns)
      end
    end

    def clear_graph_cache
      GRAPH_CACHE_MUTEX.synchronize { graph_cache.clear }
      nil
    end

    def extract_graph_uncached(root, exclude_patterns)
      source_files = enumerate_source_files(root, exclude_patterns:)
      edges = self_edges(source_files) + extract_dependencies_from(root, source_files)

      Common::Extraction::Graph.new(merge_parallel_edges(edges))
    end
    private_class_method :extract_graph_uncached

    def graph_cache_key(project_root, exclude_patterns:, options:)
      [
        project_root.to_s.tr('\\', '/').freeze,
        exclude_patterns.sort.freeze,
        graph_analysis_toggles(options)
      ].freeze
    end
    private_class_method :graph_cache_key

    def graph_analysis_toggles(options)
      options.class.members.filter_map do |member|
        next if GRAPH_INDEPENDENT_CHECK_OPTIONS.include?(member)

        [member, options.public_send(member)].freeze
      end.freeze
    end
    private_class_method :graph_analysis_toggles

    def graph_cache
      @graph_cache ||= {}
    end
    private_class_method :graph_cache

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
