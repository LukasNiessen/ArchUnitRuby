# frozen_string_literal: true

require_relative '../../common/pattern_matching'

module ArchUnit
  module GraphReporting
    module Projection
      # Pure graph traversal for focus, reachability, and dependent queries.
      module NodeSelection
        module_function

        def select(edges, options)
          return all_nodes(edges) unless query?(options)

          selected = Set.new
          selected.merge(expand_focus(edges, options.focus, options.focus_depth)) if options.focus
          selected.merge(walk(edges, options.reachable_from, :outgoing)) if options.reachable_from
          selected.merge(walk(edges, options.dependents_of, :incoming)) if options.dependents_of
          selected
        end

        def query?(options)
          options.focus || options.reachable_from || options.dependents_of
        end
        private_class_method :query?

        def all_nodes(edges)
          edges.each_with_object(Set.new) do |edge, nodes|
            nodes.add(edge.source).add(edge.target)
          end
        end
        private_class_method :all_nodes

        def expand_focus(edges, filter, depth)
          selected = matching_nodes(edges, filter)
          queue = selected.map { |node| [node, 0] }

          until queue.empty?
            current, current_depth = queue.shift
            next if current_depth >= depth

            add_neighbors(edges, current, current_depth, selected, queue)
          end
          selected
        end
        private_class_method :expand_focus

        def add_neighbors(edges, current, current_depth, selected, queue)
          neighbors_of(edges, current).each do |neighbor|
            next if selected.include?(neighbor)

            selected.add(neighbor)
            queue << [neighbor, current_depth + 1]
          end
        end
        private_class_method :add_neighbors

        def walk(edges, filter, direction)
          selected = matching_nodes(edges, filter)
          queue = selected.to_a

          until queue.empty?
            current = queue.shift
            add_next_nodes(edges, current, direction, selected, queue)
          end
          selected
        end
        private_class_method :walk

        def add_next_nodes(edges, current, direction, selected, queue)
          next_nodes(edges, current, direction).each do |node|
            next if selected.include?(node)

            selected.add(node)
            queue << node
          end
        end
        private_class_method :add_next_nodes

        def matching_nodes(edges, filter)
          all_nodes(edges).select do |node|
            Common::PatternMatching.matches_pattern?(node, filter)
          end.to_set
        end
        private_class_method :matching_nodes

        def neighbors_of(edges, node)
          edges.filter_map do |edge|
            if edge.source == node && edge.target != node
              edge.target
            elsif edge.target == node && edge.source != node
              edge.source
            end
          end.uniq
        end
        private_class_method :neighbors_of

        def next_nodes(edges, node, direction)
          edges.filter_map do |edge|
            if direction == :outgoing && edge.source == node
              edge.target
            elsif direction == :incoming && edge.target == node
              edge.source
            end
          end.uniq
        end
        private_class_method :next_nodes
      end
    end
  end
end
