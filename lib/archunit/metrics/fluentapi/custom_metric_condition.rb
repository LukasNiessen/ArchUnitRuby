# frozen_string_literal: true

require_relative '../../common/fluentapi/checkable'
require_relative '../assertion/custom_metric'

module ArchUnit
  module Metrics
    module FluentApi
      # Executable custom class-metric predicate.
      class CustomMetricCondition
        include Common::FluentApi::Checkable

        attr_reader :selection, :predicate

        def initialize(selection:, predicate:)
          unless selection.is_a?(CustomMetricBuilder)
            raise ArgumentError, 'selection must be a CustomMetricBuilder'
          end
          raise ArgumentError, 'predicate must respond to call' unless predicate.respond_to?(:call)

          @selection = selection
          @predicate = predicate.dup.freeze
          freeze
        end

        private

        def perform_check(options)
          classes = selection.scope.__send__(:subjects_for, Extraction::ClassInfo)
          empty_test = empty_test_violation(
            classes, filters: selection.scope.filters, negated: false, options:
          )
          return empty_test if empty_test

          Assertion.gather_custom_metric_violations(classes, selection.metric, predicate)
        end
      end
    end
  end
end
