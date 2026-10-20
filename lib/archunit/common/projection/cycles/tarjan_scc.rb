# frozen_string_literal: true

module ArchUnit
  module Common
    module Projection
      module Cycles
        # Finds strongly connected components in a directed adjacency map.
        class TarjanScc
          Frame = Struct.new(:vertex, :neighbours, :index)
          private_constant :Frame

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
            frames = [enter_vertex(vertex)]
            until frames.empty?
              frame = frames.last
              if frame.index < frame.neighbours.length
                inspect_neighbour(frame, frames)
              else
                finish_vertex(frames)
              end
            end
          end

          def enter_vertex(vertex)
            index_vertex(vertex)
            Frame.new(vertex, neighbours(vertex), 0)
          end

          def index_vertex(vertex)
            @indices[vertex] = @next_index
            @lowlinks[vertex] = @next_index
            @next_index += 1
            @stack << vertex
            @on_stack.add(vertex)
          end

          def inspect_neighbour(frame, frames)
            neighbour = frame.neighbours.fetch(frame.index)
            frame.index += 1
            unless @indices.key?(neighbour)
              frames << enter_vertex(neighbour)
              return
            end
            return unless @on_stack.include?(neighbour)

            update_lowlink(frame.vertex, @indices.fetch(neighbour))
          end

          def finish_vertex(frames)
            vertex = frames.pop.vertex
            extract_component(vertex) if @lowlinks.fetch(vertex) == @indices.fetch(vertex)
            update_lowlink(frames.last.vertex, @lowlinks.fetch(vertex)) unless frames.empty?
          end

          def update_lowlink(vertex, index)
            @lowlinks[vertex] = [@lowlinks.fetch(vertex), index].min
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
