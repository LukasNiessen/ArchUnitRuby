# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../../common/projection/edge_projections'
require_relative '../../common/projection/project_edges'
require_relative '../../common/regex_factory'
require_relative '../../extraction/extract_graph'
require_relative '../assertion/depend_on_files'
require_relative 'file_rule_support'

module ArchUnit
  module Files
    module FluentApi
      # Executable internal file-dependency rule with chainable object selectors.
      class DependOnFileCondition
        include Common::FluentApi::Checkable

        attr_reader :builder, :project_locator, :subject_filters, :object_filters, :is_negated

        def initialize(builder, object_filters:)
          unless builder.is_a?(DependOnFileConditionBuilder)
            raise ArgumentError, 'builder must be a DependOnFileConditionBuilder'
          end

          @builder = builder
          @project_locator = builder.project_locator
          @subject_filters = builder.subject_filters
          @object_filters = immutable_object_filters(object_filters)
          @is_negated = builder.negated?
          freeze
        end

        def negated?
          is_negated
        end

        def with_name(pattern)
          with_filter(Common::RegexFactory.filename_matcher(pattern))
        end

        def in_folder(pattern)
          with_filter(Common::RegexFactory.folder_matcher(pattern))
        end

        def in_path(pattern)
          with_filter(Common::RegexFactory.path_matcher(pattern))
        end

        private

        def immutable_object_filters(values)
          filters = Array(values).dup
          unless !filters.empty? && filters.all?(Common::Filter)
            raise ArgumentError, 'object_filters must contain at least one Filter'
          end

          filters.freeze
        end

        def with_filter(filter)
          self.class.new(builder, object_filters: [*object_filters, filter])
        end

        def perform_check(options)
          graph = Extraction.extract_graph(project_locator, options:)
          nodes = FileRuleSupport.selected_nodes(graph, subject_filters)
          empty_test = FileRuleSupport.empty_test_violation(
            nodes, subject_filters, negated: is_negated, options:
          )
          return empty_test if empty_test

          edges = Common::Projection.project_edges(graph, Common::Projection.per_internal_edge)
          Assertion.gather_file_dependency_violations(
            edges, subject_filters, object_filters, is_negated:
          )
        end
      end
    end
  end
end
