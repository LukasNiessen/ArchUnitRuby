# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../assertion/metric_predicate'

module ArchUnit
  module Metrics
    module FluentApi
      # Executable arbitrary predicate over one selected built-in metric.
      class MetricPredicateCondition
        include Common::FluentApi::Checkable

        attr_reader :selection, :predicate

        def initialize(selection:, predicate:)
          unless selection.is_a?(MetricSelection)
            raise ArgumentError, 'selection must be a MetricSelection'
          end
          raise ArgumentError, 'predicate must respond to call' unless predicate.respond_to?(:call)

          @selection = selection
          @predicate = predicate.dup.freeze
          freeze
        end

        private

        def perform_check(options)
          subjects = selection.scope.__send__(
            :subjects_for, selection.metric.subject_type, options:
          )
          empty_test = empty_test_violation(
            subjects, filters: selection.scope.filters, negated: false, options:
          )
          return empty_test if empty_test

          Assertion.gather_metric_predicate_violations(subjects, selection.metric, predicate)
        end
      end
    end
  end
end
