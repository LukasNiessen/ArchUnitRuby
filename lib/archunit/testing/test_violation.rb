# frozen_string_literal: true

module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    # Immutable human-readable representation of one structured violation.
    TestViolation = Data.define(:message, :details) do
      def initialize(message:, details:)
        message = non_empty_string(message, :message)
        details = non_empty_string(details, :details)
        super
      end

      private

      def non_empty_string(value, attribute)
        return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

        raise ArgumentError, "#{attribute} must be a non-empty String"
      end
    end
  end
end
