# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../../common/projection/projected_edge'

module ArchUnit
  module Files
    # Pure file-rule assertion functions and violation values.
    module Assertion
      # Data describing one closed circular dependency path.
      class CycleViolation < Common::Assertion::Violation
        attr_reader :cycle, :path

        def initialize(cycle:)
          @cycle = immutable_cycle(cycle)
          @path = [cycle.first.source_label, *cycle.map(&:target_label)].freeze
          super()
        end

        def ==(other)
          other.is_a?(self.class) && cycle == other.cycle
        end
        alias eql? ==

        def hash
          [self.class, cycle].hash
        end

        private

        def immutable_cycle(values)
          unless values.is_a?(Array) && !values.empty? && values.all?(Common::Projection::ProjectedEdge)
            raise ArgumentError, 'cycle must be a non-empty Array of ProjectedEdge values'
          end
          unless closed_cycle?(values)
            raise ArgumentError, 'cycle edges must form a contiguous closed path'
          end

          values.dup.freeze
        end

        def closed_cycle?(edges)
          edges.each_cons(2).all? do |current, following|
            current.target_label == following.source_label
          end && edges.last.target_label == edges.first.source_label
        end
      end

      module_function

      def gather_cycle_violations(cycles)
        raise ArgumentError, 'cycles must be an Array' unless cycles.is_a?(Array)

        cycles.map { |cycle| CycleViolation.new(cycle:) }
      end
    end
  end
end
