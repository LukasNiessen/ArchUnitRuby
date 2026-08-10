# frozen_string_literal: true

require_relative 'tarjan_scc'

module ArchUnit
  module Common
    module Projection
      module Cycles
        # Enumerates every elementary directed cycle once using Johnson's algorithm.
        class JohnsonCycles
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
            @stack << vertex
            @blocked.add(vertex)
            found_cycle = explore_neighbours(vertex)
            found_cycle ? unblock(vertex) : record_blockers(vertex)
            @stack.pop
            found_cycle
          end

          def explore_neighbours(vertex)
            found_cycle = false
            component_neighbours(vertex).each do |neighbour|
              closes_cycle = record_cycle?(neighbour)
              finds_cycle = !@blocked.include?(neighbour) && circuit(neighbour)
              found_cycle = true if closes_cycle || finds_cycle
            end
            found_cycle
          end

          def record_cycle?(neighbour)
            return false unless neighbour == @start

            @cycles << @stack.dup
            true
          end

          def unblock(vertex)
            return unless @blocked.delete?(vertex)

            dependants = @blocked_by.delete(vertex) || []
            dependants.each { |dependant| unblock(dependant) }
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
