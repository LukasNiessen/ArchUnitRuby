# frozen_string_literal: true

require 'pathname'
require_relative '../common/extraction/edge'
require_relative '../common/extraction/graph'
require_relative '../common/fluentapi/check_options'
require_relative 'enumerate_source_files'
require_relative 'extract_dependencies'
require_relative 'extraction_profile'
require_relative 'locate_project'
require_relative 'resolve_load_paths'

module ArchUnit
  # Assembles the normalized dependency graph for a Ruby project.
  module Extraction
    GRAPH_CACHE_MUTEX = Mutex.new
    GRAPH_INDEPENDENT_CHECK_OPTIONS = %i[allow_empty_tests logging clear_cache].freeze

    module_function

    def extract_graph(
      locator = nil, exclude_patterns: nil, options: nil, working_directory: Dir.pwd,
      profile: nil
    )
      ExtractionProfile.validate(profile)
      options = Common::FluentApi::CheckOptions.resolve(options)
      ExtractionProfile.measure(profile, :total) do
        root = ExtractionProfile.measure(profile, :project_discovery) do
          Pathname.new(locate_project(locator, working_directory:))
        end
        patterns = resolve_exclude_patterns(exclude_patterns)
        cache_key = graph_cache_key(root, exclude_patterns: patterns, options:)

        fetch_graph(root, patterns, options, cache_key, profile)
      end
    end

    def clear_graph_cache
      GRAPH_CACHE_MUTEX.synchronize { graph_cache.clear }
      nil
    end

    def fetch_graph(root, patterns, options, cache_key, profile)
      GRAPH_CACHE_MUTEX.synchronize do
        graph_cache.delete(cache_key) if options.clear_cache?
        cached = graph_cache[cache_key]
        if cached
          profile&.record_cache_hit
          return cached
        end

        graph_cache[cache_key] = extract_graph_uncached(root, patterns, options, profile)
      end
    end
    private_class_method :fetch_graph

    def extract_graph_uncached(root, exclude_patterns, options, profile)
      source_files = ExtractionProfile.measure(profile, :source_enumeration) do
        enumerate_source_files(root, exclude_patterns:)
      end
      profile&.increment(:source_files, source_files.length)
      load_paths = ExtractionProfile.measure(profile, :load_path_discovery) do
        LoadPaths.resolve(root, explicit_paths: options.load_paths, source_files:)
      end
      edges = extraction_edges(root, source_files, load_paths, profile)
      graph_from_edges(edges, profile)
    end
    private_class_method :extract_graph_uncached

    def extraction_edges(root, source_files, load_paths, profile)
      edges = self_edges(source_files) + extract_dependencies_from(
        root, source_files, load_paths:, profile:
      )
      profile&.increment(:raw_edges, edges.length)
      edges
    end
    private_class_method :extraction_edges

    def graph_from_edges(edges, profile)
      merged = ExtractionProfile.measure(profile, :edge_merge) do
        merge_parallel_edges(edges)
      end
      profile&.increment(:merged_edges, merged.length)
      Common::Extraction::Graph.new(merged)
    end
    private_class_method :graph_from_edges

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
