# frozen_string_literal: true

require_relative 'folder_depth_collapse'
require_relative 'pattern_collapse'

module ArchUnit
  module GraphReporting
    module Projection
      # Pure node-label collapsing shared by snapshot nodes and edges.
      module CollapseNode
        module_function

        def collapse(node, strategy)
          return node if strategy.nil?
          return node.gsub(strategy.regexp, strategy.replacement) if strategy.is_a?(PatternCollapse)

          collapse_to_folder(node, strategy.depth)
        end

        def collapse_to_folder(node, depth)
          parts = node.split('/').reject(&:empty?)
          return node if parts.length <= 1

          folders = parts[0...-1]
          return node if folders.empty?

          folders.first(depth).join('/')
        end
        private_class_method :collapse_to_folder
      end
    end
  end
end
