# frozen_string_literal: true

module ArchUnit
  module Common
    module Projection
      module Cycles
        # Finds strongly connected components in a directed adjacency map.
        class TarjanScc
          def self.call(adjacency, vertices: adjacency.keys)
            new(adjacency, vertices).call
          end

          def initialize(adjacency, vertices)
            @adjacency = adjacency
            @vertices = vertices.to_a
            @allowed = @vertices.to_set
            @next_index = 0
            @indices = {}
            @lowlinks = {}
            @stack = []
            @on_stack = Set.new
            @components = []
          end

          def call
            @vertices.each { |vertex| visit(vertex) unless @indices.key?(vertex) }
            @components.map(&:freeze).freeze
          end

          private

          def visit(vertex)
            index_vertex(vertex)

            neighbours(vertex).each do |neighbour|
              inspect_neighbour(vertex, neighbour)
            end

            extract_component(vertex) if @lowlinks.fetch(vertex) == @indices.fetch(vertex)
          end

          def index_vertex(vertex)
            @indices[vertex] = @next_index
            @lowlinks[vertex] = @next_index
            @next_index += 1
            @stack << vertex
            @on_stack.add(vertex)
          end

          def inspect_neighbour(vertex, neighbour)
            unless @indices.key?(neighbour)
              visit(neighbour)
              @lowlinks[vertex] = [@lowlinks.fetch(vertex), @lowlinks.fetch(neighbour)].min
              return
            end

            return unless @on_stack.include?(neighbour)

            @lowlinks[vertex] = [@lowlinks.fetch(vertex), @indices.fetch(neighbour)].min
          end

          def extract_component(root)
            component = []

            loop do
              vertex = @stack.pop
              @on_stack.delete(vertex)
              component << vertex
              break if vertex == root
            end

            @components << component.sort
          end

          def neighbours(vertex)
            @adjacency.fetch(vertex, []).select { |neighbour| @allowed.include?(neighbour) }
          end
        end
      end
    end
  end
end
