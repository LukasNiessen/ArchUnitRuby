# frozen_string_literal: true

require_relative 'edge'

module ArchUnit
  module Common
    module Extraction
      # An immutable, enumerable list of dependency edges.
      class Graph
        include Enumerable

        attr_reader :edges

        def initialize(edges = [])
          @edges = Array(edges).dup
          invalid_edges = @edges.grep_v(Edge)
          raise ArgumentError, 'graph accepts only Edge values' unless invalid_edges.empty?

          validate_identifier_style
          @edges.freeze
          freeze
        end

        def each(&)
          edges.each(&)
        end

        def [](*)
          edges[*]
        end

        def size
          edges.size
        end
        alias length size

        def empty?
          edges.empty?
        end

        def to_a
          edges.dup
        end

        def ==(other)
          other.is_a?(Graph) && edges == other.edges
        end
        alias eql? ==

        def hash
          [self.class, edges].hash
        end

        private

        def validate_identifier_style
          identifiers = edges.flat_map do |edge|
            edge.external ? [edge.source] : [edge.source, edge.target]
          end
          styles = identifiers.map { |identifier| absolute_identifier?(identifier) }.uniq
          return if styles.length <= 1

          raise ArgumentError,
                'graph identifiers must be either all absolute or all project-relative'
        end

        def absolute_identifier?(identifier)
          identifier.start_with?('/') || identifier.match?(%r{\A[A-Za-z]:/})
        end
      end
    end
  end
end
