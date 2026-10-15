# frozen_string_literal: true

require_relative 'import_kind'

module ArchUnit
  module Common
    module Extraction
      # Source-level support for a file dependency, without implying runtime execution.
      DependencyEvidence = Data.define(
        :source, :kind, :name, :line_number, :end_line, :target_line_number
      ) do
        # rubocop:disable Metrics/ParameterLists -- Keywords mirror this immutable source span.
        def initialize(source:, kind:, name:, line_number:, end_line: line_number,
                       target_line_number: nil)
          validate_identity(source, kind, name)
          validate_lines(line_number, end_line, target_line_number)
          source = source.tr('\\', '/').freeze
          name = name.dup.freeze
          super
        end
        # rubocop:enable Metrics/ParameterLists

        private

        def validate_identity(source, kind, name)
          return if source.is_a?(String) && name.is_a?(String) && ImportKind.valid?(kind)

          raise ArgumentError, 'evidence requires a source, name, and valid dependency kind'
        end

        def validate_lines(first, last, target)
          valid = positive_line?(first) && positive_line?(last) && last >= first
          return if valid && (target.nil? || positive_line?(target))

          raise ArgumentError, 'evidence requires valid source line numbers'
        end

        def positive_line?(value)
          value.is_a?(Integer) && value.positive?
        end
      end
    end
  end
end
