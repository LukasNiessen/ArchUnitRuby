# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../assertion/metric_threshold'

module ArchUnit
  module Metrics
    module FluentApi
      # Executable numeric threshold over one selected metric.
      class MetricThresholdCondition
        include Common::FluentApi::Checkable

        attr_reader :selection, :comparison, :threshold

        def initialize(selection:, comparison:, threshold:)
          unless selection.is_a?(MetricSelection)
            raise ArgumentError, 'selection must be a MetricSelection'
          end
          unless Assertion::MetricThresholdViolation::COMPARISONS.include?(comparison)
            raise ArgumentError, "unknown metric comparison: #{comparison.inspect}"
          end

          @selection = selection
          @comparison = comparison
          @threshold = Calculation::NumericValue.validate(threshold, attribute: 'threshold')
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

          Assertion.gather_metric_threshold_violations(
            subjects, selection.metric, comparison, threshold
          )
        end
      end
    end
  end
end
