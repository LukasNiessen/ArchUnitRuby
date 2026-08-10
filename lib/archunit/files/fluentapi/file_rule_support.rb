# frozen_string_literal: true

require_relative '../../common/assertion/empty_test_violation'
require_relative '../../common/pattern_matching'
require_relative '../../common/projection/project_to_nodes'

module ArchUnit
  module Files
    module FluentApi
      # Shared file selection and empty-test handling for executable rule terminals.
      module FileRuleSupport
        module_function

        def selected_nodes(graph, filters)
          nodes = Common::Projection.project_to_nodes(graph)
          return nodes if filters.empty?

          nodes.select do |node|
            Common::PatternMatching.matches_all_patterns?(node.label, filters)
          end
        end

        def empty_test_violation(nodes, filters, negated:, options:)
          return if !nodes.empty? || options.allow_empty_tests?

          [Common::Assertion::EmptyTestViolation.new(filters:, is_negated: negated)]
        end
      end
    end
  end
end
