# frozen_string_literal: true

module ArchUnit
  module Common
    module Logging
      # Internal inspection context, scoped to one check and isolated by Ruby fiber.
      module Inspection
        module_function

        def with(logger)
          previous = Thread.current[:archunit_inspection_logger]
          Thread.current[:archunit_inspection_logger] = logger
          yield
        ensure
          Thread.current[:archunit_inspection_logger] = previous
        end

        def logger
          Thread.current[:archunit_inspection_logger]
        end

        def debug(&)
          logger&.debug(&)
        end

        def graph(graph, root:)
          debug do
            logger.debug { "project root: #{root.to_s.inspect}" }
            graph.each { |edge| logger.debug { describe_edge(edge) } }
            "graph edges: #{graph.size}"
          end
          graph
        end

        def selection(label, items)
          debug do
            items.each { |item| logger.debug { "#{label}: #{yield(item).inspect}" } }
            "#{label} count: #{items.length}"
          end
          items
        end

        def projection(edges)
          selection('projected dependency', edges) do |edge|
            "#{edge.source_label} -> #{edge.target_label} (#{edge.cumulated_edges.length} edges)"
          end
        end

        def describe_edge(edge)
          return "discovered file: #{edge.source.inspect}" if edge.source == edge.target

          "dependency: #{edge.source.inspect} -> #{edge.target.inspect} " \
            "(external=#{edge.external}, kinds=#{edge.import_kinds.inspect})"
        end
        private_class_method :describe_edge
      end
    end
  end
end
