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
      end
    end
  end
end
