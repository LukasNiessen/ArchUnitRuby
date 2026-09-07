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
      # @!method to_dot
      #   @return [String] the current graph report as Graphviz DOT
      # @!method to_mermaid
      #   @return [String] the current graph report as Mermaid
      # @!method to_d2
      #   @return [String] the current graph report as D2
      # @!method to_csv
      #   @return [String] the current graph report as CSV
      # @!method to_json
      #   @return [String] the current graph report as JSON
      # @!method to_html
      #   @return [String] the current graph report as self-contained HTML
      # @!method export_as_dot(output_path)
      #   @return [nil] writes Graphviz DOT to output_path
      # @!method export_as_mermaid(output_path)
      #   @return [nil] writes Mermaid to output_path
      # @!method export_as_d2(output_path)
      #   @return [nil] writes D2 to output_path
      # @!method export_as_csv(output_path)
      #   @return [nil] writes CSV to output_path
      # @!method export_as_json(output_path)
      #   @return [nil] writes JSON to output_path
      # @!method export_as_html(output_path)
      #   @return [nil] writes self-contained HTML to output_path
      class ProjectGraphBuilder
        attr_reader :project_locator, :options, :check_options

        def initialize(project_locator: nil, options: nil, check_options: nil)
          @project_locator = immutable_project_locator(project_locator)
          @options = Projection::GraphQueryOptions.resolve(options)
          @check_options = immutable_check_options(check_options)
          freeze
        end

        # Includes standard-library and gem imports in the report.
        # @return [ProjectGraphBuilder]
        def include_external_dependencies
          with_options(options.with(include_external_dependencies: true))
        end

        # Includes the self-edges that represent dependency-free source files.
        # @return [ProjectGraphBuilder]
        def include_self_dependencies
          with_options(options.with(include_self_dependencies: true))
        end

        # Keeps matching nodes and neighbors within depth hops.
        # @return [ProjectGraphBuilder]
        def focus_on(pattern, depth = 1, except: nil)
          filter = Common::RegexFactory.path_matcher(pattern, except:)
          with_options(options.with(focus: filter, focus_depth: depth))
        end

        # Keeps nodes reachable from matching starting nodes.
        # @return [ProjectGraphBuilder]
        def reachable_from(pattern, except: nil)
          filter = Common::RegexFactory.path_matcher(pattern, except:)
          with_options(options.with(reachable_from: filter))
        end

        # Keeps matching nodes and everything that depends on them.
        # @return [ProjectGraphBuilder]
        def dependents_of(pattern, except: nil)
          filter = Common::RegexFactory.path_matcher(pattern, except:)
          with_options(options.with(dependents_of: filter))
        end

        # Groups file nodes by the requested project-relative folder depth.
        # @return [ProjectGraphBuilder]
        def collapse_to_folder_depth(depth)
          with_options(options.with(collapse: Projection::FolderDepthCollapse.new(depth:)))
        end

        # Groups node names through a regular-expression replacement.
        # @return [ProjectGraphBuilder]
        def collapse_by_pattern(pattern, replacement = '\\1')
          collapse = Projection::PatternCollapse.from(pattern, replacement)
          with_options(options.with(collapse:))
        end

        # Sets the report title.
        # @return [ProjectGraphBuilder]
        def titled(title)
          with_options(options.with(title:))
        end

        # Attaches extraction-related CheckOptions to this report.
        # @return [ProjectGraphBuilder]
        def with_check_options(value)
          self.class.new(project_locator:, options:, check_options: value)
        end

        # @return [GraphReportSnapshot] the immutable queried graph
        def snapshot
          graph = ArchUnit::Extraction.extract_graph(project_locator, options: check_options)
          Projection::SnapshotFactory.create(graph, options)
        end

        # @return [GraphReportSummary] counts for the current snapshot
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
