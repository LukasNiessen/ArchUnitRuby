# frozen_string_literal: true

require_relative '../../extraction/extract_graph'
require_relative 'distance_info'
require_relative 'extract_project_info'

module ArchUnit
  module Metrics
    # Ruby-specific extraction enriched with dependency coupling.
    module Extraction
      module_function

      # Enriches static file facts with distinct internal incoming/outgoing dependencies.
      def extract_distance_infos(project_locator = nil, options: nil)
        project = extract_project_info(project_locator)
        graph = ArchUnit::Extraction.extract_graph(project.project_root, options:)
        outgoing, incoming = coupling_indexes(graph, project.files.map(&:path))
        build_distance_infos(project, outgoing, incoming)
      end

      def build_distance_infos(project, outgoing, incoming)
        project.files.map do |file_info|
          DistanceInfo.new(
            file_info:,
            afferent_coupling: incoming.fetch(file_info.path, []).length,
            efferent_coupling: outgoing.fetch(file_info.path, []).length,
            project_file_count: project.files.length
          )
        end.freeze
      end
      private_class_method :build_distance_infos

      # rubocop:disable Metrics/AbcSize -- Both directional indexes are built in one graph pass.
      def coupling_indexes(graph, file_paths)
        outgoing = Hash.new { |hash, key| hash[key] = [] }
        incoming = Hash.new { |hash, key| hash[key] = [] }
        graph.each do |edge|
          next if edge.external || edge.source == edge.target
          next unless file_paths.include?(edge.source) && file_paths.include?(edge.target)

          outgoing[edge.source] |= [edge.target]
          incoming[edge.target] |= [edge.source]
        end
        [outgoing, incoming]
      end
      # rubocop:enable Metrics/AbcSize
      private_class_method :coupling_indexes
    end
  end
end
