# frozen_string_literal: true

require_relative 'tarjan_scc'

module ArchUnit
  module Common
    module Projection
      module Cycles
        # Enumerates every elementary directed cycle once using Johnson's algorithm.
        class JohnsonCycles
          Frame = Struct.new(:vertex, :neighbours, :index, :found_cycle)
          private_constant :Frame

          def self.call(adjacency)
            new(adjacency).call
          end

          def initialize(adjacency)
            @vertices = (adjacency.keys + adjacency.values.flatten).uniq.sort
            @adjacency = @vertices.to_h do |vertex|
              neighbours = adjacency.fetch(vertex, []).reject { |item| item == vertex }.uniq.sort
              [vertex, neighbours]
            end
            @cycles = []
          end

          def call
            lower_bound = @vertices.first

            while lower_bound
              component = next_component(lower_bound)
              break unless component

              start = component.min
              prepare_search(component, start)
              circuit(start)
              lower_bound = @vertices.find { |vertex| vertex > start }
            end

            @cycles.map(&:freeze).freeze
          end

          private

          def next_component(lower_bound)
            remaining = @vertices.select { |vertex| vertex >= lower_bound }
            TarjanScc.call(@adjacency, vertices: remaining)
                     .select { |component| component.length > 1 }
                     .min_by(&:min)
          end

          def prepare_search(component, start)
            @component = component.to_set
            @start = start
            @stack = []
            @blocked = Set.new
            @blocked_by = Hash.new { |hash, vertex| hash[vertex] = Set.new }
          end

          def circuit(vertex)
            frames = [enter_vertex(vertex)]
            until frames.empty?
              frame = frames.last
              if frame.index < frame.neighbours.length
                explore_neighbour(frame, frames)
              else
                finish_vertex(frames)
              end
            end
          end

          def enter_vertex(vertex)
            @stack << vertex
            @blocked.add(vertex)
            Frame.new(vertex, component_neighbours(vertex), 0, false)
          end

          def explore_neighbour(frame, frames)
            neighbour = frame.neighbours.fetch(frame.index)
            frame.index += 1
            if neighbour == @start
              @cycles << @stack.dup
              frame.found_cycle = true
            elsif !@blocked.include?(neighbour)
              frames << enter_vertex(neighbour)
            end
          end

          def finish_vertex(frames)
            frame = frames.pop
            frame.found_cycle ? unblock(frame.vertex) : record_blockers(frame.vertex)
            @stack.pop
            frames.last.found_cycle ||= frame.found_cycle unless frames.empty?
          end

          def unblock(vertex)
            pending = [vertex]
            until pending.empty?
              candidate = pending.pop
              next unless @blocked.delete?(candidate)

              pending.concat((@blocked_by.delete(candidate) || []).to_a)
            end
          end

          def record_blockers(vertex)
            component_neighbours(vertex).each do |neighbour|
              @blocked_by[neighbour].add(vertex)
            end
          end

          def component_neighbours(vertex)
            @adjacency.fetch(vertex, []).select { |neighbour| @component.include?(neighbour) }
          end
        end
      end
    end
  end
end
