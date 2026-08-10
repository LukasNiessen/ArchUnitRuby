# frozen_string_literal: true

require_relative '../../common/extraction/edge'
require_relative '../../common/pattern_matching'
require_relative '../../common/projection/mapped_edge'

module ArchUnit
  module Slices
    # Projections from file dependencies into architectural slices.
    module Projection
      # Immutable callable mapper that also exposes the selected internal slice names.
      class SliceProjection
        def initialize(&labeler)
          raise ArgumentError, 'a slice labeler block is required' unless labeler

          @labeler = labeler.freeze
          freeze
        end

        def call(edge)
          validate_edge(edge)
          return if edge.source == edge.target

          source_label = label_for(edge.source)
          return unless source_label

          target_label = edge.external ? edge.target : label_for(edge.target)
          return unless target_label
          return if !edge.external && source_label == target_label

          Common::Projection::MappedEdge.new(source_label:, target_label:)
        end

        def slice_labels(graph)
          labels = []
          each_edge(graph) do |edge|
            labels << label_for(edge.source)
            labels << label_for(edge.target) unless edge.external
          end
          labels.compact.uniq.sort.freeze
        end

        def label_for(path)
          unless path.is_a?(String) && !path.empty?
            raise ArgumentError, 'path must be a non-empty String'
          end

          label = @labeler.call(Common::PatternMatching.normalize_path(path))
          return if label.nil?
          return label.dup.freeze if label.is_a?(String) && !label.empty?

          raise TypeError, 'slice labelers must return a non-empty String or nil'
        end

        private

        def each_edge(graph)
          unless graph.respond_to?(:each)
            raise ArgumentError, 'graph must be an enumerable of Edge values'
          end

          graph.each do |edge|
            validate_edge(edge)
            yield edge
          end
        end

        def validate_edge(value)
          return if value.is_a?(Common::Extraction::Edge)

          raise ArgumentError, 'graph must contain only Edge values'
        end
      end
    end
  end
end
