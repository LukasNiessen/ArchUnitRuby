# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../../common/filter'
require_relative '../../common/pattern_matching'
require_relative '../../common/projection/projected_node'

module ArchUnit
  module Files
    # Pure file-pattern assertion functions and violation values.
    module Assertion
      # Data describing a selected file that disagrees with a pattern predicate.
      class FilePatternViolation < Common::Assertion::Violation
        attr_reader :check_filter, :projected_node, :is_negated

        def initialize(check_filter:, projected_node:, is_negated: false)
          @check_filter = filter_value(check_filter)
          @projected_node = node_value(projected_node)
          @is_negated = boolean_value(is_negated)
          super()
        end

        def negated?
          is_negated
        end

        def ==(other)
          other.is_a?(self.class) &&
            check_filter == other.check_filter &&
            projected_node == other.projected_node &&
            is_negated == other.is_negated
        end
        alias eql? ==

        def hash
          [self.class, check_filter, projected_node, is_negated].hash
        end

        private

        def filter_value(value)
          return value if value.is_a?(Common::Filter)

          raise ArgumentError, 'check_filter must be a Filter'
        end

        def node_value(value)
          return value if value.is_a?(Common::Projection::ProjectedNode)

          raise ArgumentError, 'projected_node must be a ProjectedNode'
        end

        def boolean_value(value)
          return value if [true, false].include?(value)

          raise ArgumentError, 'is_negated must be true or false'
        end
      end

      module_function

      def gather_matching_file_violations(nodes, check_filter, is_negated:)
        validate_matching_arguments(nodes, check_filter, is_negated)

        nodes.filter_map do |node|
          matches = Common::PatternMatching.matches_pattern?(node.label, check_filter)
          next unless is_negated ? matches : !matches

          FilePatternViolation.new(check_filter:, projected_node: node, is_negated:)
        end
      end

      def validate_matching_arguments(nodes, check_filter, is_negated)
        unless nodes.is_a?(Array) && nodes.all?(Common::Projection::ProjectedNode)
          raise ArgumentError, 'nodes must be an Array of ProjectedNode values'
        end
        unless check_filter.is_a?(Common::Filter)
          raise ArgumentError, 'check_filter must be a Filter'
        end
        return if [true, false].include?(is_negated)

        raise ArgumentError, 'is_negated must be true or false'
      end
      private_class_method :validate_matching_arguments
    end
  end
end
