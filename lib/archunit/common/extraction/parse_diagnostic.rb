# frozen_string_literal: true

module ArchUnit
  module Common
    module Extraction
      # Immutable parser failure location; line and column are both one-based.
      ParseDiagnostic = Data.define(:path, :line, :column, :message) do
        def initialize(path:, line:, column:, message:)
          unless [path, message].all? { |value| value.is_a?(String) && !value.empty? }
            raise ArgumentError, 'parse diagnostic requires a non-empty path and message'
          end
          unless [line, column].all? { |value| value.is_a?(Integer) && value.positive? }
            raise ArgumentError, 'parse diagnostic coordinates must be positive integers'
          end

          path = path.tr('\\', '/').freeze
          message = message.dup.freeze
          super
        end
      end
    end
  end
end
