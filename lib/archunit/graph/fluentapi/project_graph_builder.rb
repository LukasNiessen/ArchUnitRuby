# frozen_string_literal: true

require_relative '../../common/fluentapi/check_options'
require_relative '../../common/regex_factory'
require_relative '../../extraction/extract_graph'
require_relative '../projection/create_snapshot'
require_relative '../rendering/graph_renderer'

module ArchUnit
  module GraphReporting
    module FluentApi
      # Immutable query builder for dependency graph snapshots and reports.
      class ProjectGraphBuilder
        attr_reader :project_locator, :options, :check_options

        def initialize(project_locator: nil, options: nil, check_options: nil)
          @project_locator = immutable_project_locator(project_locator)
          @options = Projection::GraphQueryOptions.resolve(options)
          @check_options = immutable_check_options(check_options)
          freeze
        end

        def include_external_dependencies
          with_options(options.with(include_external_dependencies: true))
        end

        def include_self_dependencies
          with_options(options.with(include_self_dependencies: true))
        end

        def focus_on(pattern, depth = 1)
          filter = Common::RegexFactory.path_matcher(pattern)
          with_options(options.with(focus: filter, focus_depth: depth))
        end

        def reachable_from(pattern)
          with_options(options.with(reachable_from: Common::RegexFactory.path_matcher(pattern)))
        end

        def dependents_of(pattern)
          with_options(options.with(dependents_of: Common::RegexFactory.path_matcher(pattern)))
        end

        def collapse_to_folder_depth(depth)
          with_options(options.with(collapse: Projection::FolderDepthCollapse.new(depth:)))
        end

        def collapse_by_pattern(pattern, replacement = '\\1')
          collapse = Projection::PatternCollapse.from(pattern, replacement)
          with_options(options.with(collapse:))
        end

        def titled(title)
          with_options(options.with(title:))
        end

        def with_check_options(value)
          self.class.new(project_locator:, options:, check_options: value)
        end

        def snapshot
          graph = ArchUnit::Extraction.extract_graph(project_locator, options: check_options)
          Projection::SnapshotFactory.create(graph, options)
        end

        def summary
          snapshot.summary
        end

        Rendering::GraphRenderer::RENDERERS.each_key do |format|
          define_method("to_#{format}") do
            Rendering::GraphRenderer.render(snapshot, format)
          end

          define_method("export_as_#{format}") do |output_path|
            Rendering::GraphRenderer.export(snapshot, format, output_path)
          end
        end

        private

        def with_options(new_options)
          self.class.new(project_locator:, options: new_options, check_options:)
        end

        def immutable_project_locator(locator)
          return if locator.nil?

          locator = locator.to_path if locator.respond_to?(:to_path)
          return locator.dup.freeze if locator.is_a?(String) && !locator.empty?

          raise ArgumentError, 'project_locator must be a non-empty path or nil'
        end

        def immutable_check_options(value)
          return if value.nil?
          return value if value.is_a?(Common::FluentApi::CheckOptions)

          raise ArgumentError, 'check_options must be a CheckOptions value or nil'
        end
      end
    end
  end
end
