# frozen_string_literal: true

require_relative '../common/assertion/empty_test_violation'
require_relative '../common/assertion/violation'
require_relative '../files/assertion/custom_file_condition'
require_relative '../files/assertion/cycle_free'
require_relative '../files/assertion/depend_on_external_modules'
require_relative '../files/assertion/depend_on_files'
require_relative '../files/assertion/matching_files'
require_relative '../layers/assertion/layer_dependency_violation'
require_relative '../metrics/assertion/custom_metric'
require_relative '../metrics/assertion/metric_predicate'
require_relative '../metrics/assertion/metric_threshold'
require_relative '../metrics/assertion/metric_zone'
require_relative '../slices/assertion/slice_dependency_violation'
require_relative 'layer_violation_formatter'
require_relative 'metric_violation_formatter'
require_relative 'slice_violation_formatter'
require_relative 'test_violation'

module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    # The sole mapping from structured violation data to human-readable prose.
    class ViolationFactory
      extend LayerViolationFormatter
      extend MetricViolationFormatter
      extend SliceViolationFormatter

      FORMATTERS = {
        Common::Assertion::EmptyTestViolation => :empty_test,
        Files::Assertion::FilePatternViolation => :file_pattern,
        Files::Assertion::FileDependencyViolation => :file_dependency,
        Files::Assertion::ExternalModuleDependencyViolation => :external_module_dependency,
        Files::Assertion::CycleViolation => :cycle,
        Files::Assertion::CustomFileViolation => :custom_file,
        Layers::Assertion::LayerDependencyViolation => :layer_dependency,
        Slices::Assertion::SliceDependencyViolation => :slice_dependency
      }.merge(MetricViolationFormatter::FORMATTERS).freeze

      class << self
        def from_violation(violation)
          unless violation.is_a?(Common::Assertion::Violation)
            raise ArgumentError, 'violation must be a Violation'
          end

          formatter = FORMATTERS.find { |type, _method| violation.is_a?(type) }&.last
          formatter ? send(formatter, violation) : generic(violation)
        end

        private

        def empty_test(violation)
          selectors = violation.filters.map { |filter| describe_filter(filter) }
          details = if selectors.empty?
                      'The unfiltered rule scope contained no files.'
                    else
                      "No files matched: #{selectors.join(' AND ')}."
                    end
          TestViolation.new(message: 'No files matched the rule scope', details:)
        end

        def file_pattern(violation)
          relationship = violation.negated? ? 'matches forbidden' : 'does not match required'
          TestViolation.new(
            message: 'File pattern violation',
            details: "File '#{violation.projected_node.label}' #{relationship} " \
                     "#{describe_filter(violation.check_filter)}."
          )
        end

        def file_dependency(violation)
          edge = violation.dependency
          relationship = if violation.negated?
                           'depends on forbidden file'
                         else
                           'depends on file outside the allowed target set'
                         end
          TestViolation.new(
            message: 'File dependency violation',
            details: "File '#{edge.source_label}' #{relationship} '#{edge.target_label}'."
          )
        end

        def external_module_dependency(violation)
          edge = violation.dependency
          relationship = if violation.negated?
                           'depends on forbidden external module'
                         else
                           'depends on external module outside the allowlist'
                         end
          TestViolation.new(
            message: 'External module dependency violation',
            details: "File '#{edge.source_label}' #{relationship} '#{edge.target_label}'."
          )
        end

        def cycle(violation)
          TestViolation.new(
            message: 'Circular dependency detected',
            details: "Cycle: #{violation.path.join(' -> ')}."
          )
        end

        def custom_file(violation)
          relationship = if violation.negated?
                           'matched the forbidden predicate'
                         else
                           'failed the predicate'
                         end
          TestViolation.new(
            message: violation.message,
            details: "File '#{violation.file_info.path}' #{relationship}."
          )
        end

        def generic(violation)
          TestViolation.new(
            message: 'Architecture violation',
            details: "Unformatted violation type: #{violation.class.name}."
          )
        end

        def describe_filter(filter)
          target = {
            filename: 'filename',
            path_without_filename: 'folder',
            path: 'path',
            classname: 'class name'
          }.fetch(filter.target)
          "#{target} pattern /#{filter.regexp.source}/ (#{filter.matching})"
        end
      end

      private_class_method :new
    end
  end
end
