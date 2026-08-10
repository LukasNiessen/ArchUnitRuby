# frozen_string_literal: true

require_relative '../../common/filter'
require_relative 'folder_depth_collapse'
require_relative 'pattern_collapse'

module ArchUnit
  module GraphReporting
    module Projection
      # Immutable selection, collapsing, and presentation options for a graph snapshot.
      GraphQueryOptions = Data.define(
        :include_external_dependencies, :include_self_dependencies,
        :focus, :focus_depth, :reachable_from, :dependents_of,
        :collapse, :title
      ) do
        def self.resolve(value)
          return new if value.nil?
          return value if value.is_a?(self)

          raise ArgumentError, 'options must be a GraphQueryOptions value or nil'
        end

        # The options bag deliberately mirrors the eight independent fluent modifiers.
        # rubocop:disable Metrics/ParameterLists
        def initialize(
          include_external_dependencies: false, include_self_dependencies: false,
          focus: nil, focus_depth: 1, reachable_from: nil, dependents_of: nil,
          collapse: nil, title: nil
        )
          validate_boolean(include_external_dependencies, :include_external_dependencies)
          validate_boolean(include_self_dependencies, :include_self_dependencies)
          validate_filter(focus, :focus)
          validate_focus_depth(focus_depth)
          validate_filter(reachable_from, :reachable_from)
          validate_filter(dependents_of, :dependents_of)
          validate_collapse(collapse)
          title = immutable_title(title)
          super
        end
        # rubocop:enable Metrics/ParameterLists

        def with(**overrides)
          self.class.new(**to_h, **overrides)
        end

        private

        def validate_boolean(value, attribute)
          return if [true, false].include?(value)

          raise ArgumentError, "#{attribute} must be true or false"
        end

        def validate_filter(value, attribute)
          return if value.nil? || value.is_a?(Common::Filter)

          raise ArgumentError, "#{attribute} must be a Filter or nil"
        end

        def validate_focus_depth(value)
          return if value.is_a?(Integer) && !value.negative?

          raise ArgumentError, 'focus_depth must be a non-negative Integer'
        end

        def validate_collapse(value)
          return if value.nil? || value.is_a?(FolderDepthCollapse) || value.is_a?(PatternCollapse)

          raise ArgumentError, 'collapse must be a graph collapse strategy or nil'
        end

        def immutable_title(value)
          return if value.nil?
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, 'title must be a non-empty String or nil'
        end
      end
    end
  end
end
