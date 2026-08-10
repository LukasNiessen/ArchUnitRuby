# frozen_string_literal: true

module ArchUnit
  # Violation presentation and test-framework integration.
  module Testing
    # Immutable framework-neutral pass flag and formatted message.
    TestResult = Data.define(:passed, :message) do
      def initialize(passed:, message:)
        raise ArgumentError, 'passed must be true or false' unless [true, false].include?(passed)
        unless message.is_a?(String) && !message.empty?
          raise ArgumentError, 'message must be a non-empty String'
        end

        super(passed:, message: message.dup.freeze)
      end

      def passed?
        passed
      end

      def failed?
        !passed
      end
    end
  end
end
