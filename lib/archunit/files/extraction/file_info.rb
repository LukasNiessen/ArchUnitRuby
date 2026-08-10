# frozen_string_literal: true

module ArchUnit
  module Files
    # Ruby-specific descriptive data extraction for file rules.
    module Extraction
      # Immutable source-file information exposed to custom predicates.
      FileInfo = Data.define(
        :path, :name, :extension, :directory, :content, :lines_of_code
      ) do
        # rubocop:disable Metrics/ParameterLists -- FileInfo has six required public fields.
        def initialize(path:, name:, extension:, directory:, content:, lines_of_code:)
          path = immutable_string(path, :path, allow_empty: false, normalize_path: true)
          name = immutable_string(name, :name, allow_empty: false)
          extension = immutable_string(extension, :extension, allow_empty: true)
          directory = immutable_string(
            directory, :directory, allow_empty: true, normalize_path: true
          )
          content = immutable_string(content, :content, allow_empty: true)
          lines_of_code = non_negative_integer(lines_of_code)
          super
        end
        # rubocop:enable Metrics/ParameterLists

        private

        def immutable_string(value, attribute, allow_empty:, normalize_path: false)
          valid = value.is_a?(String) && (allow_empty || !value.empty?)
          unless valid
            requirement = allow_empty ? 'a String' : 'a non-empty String'
            raise ArgumentError, "#{attribute} must be #{requirement}"
          end

          value = value.tr('\\', '/') if normalize_path
          value.dup.freeze
        end

        def non_negative_integer(value)
          return value if value.is_a?(Integer) && value >= 0

          raise ArgumentError, 'lines_of_code must be a non-negative Integer'
        end
      end
    end
  end
end
