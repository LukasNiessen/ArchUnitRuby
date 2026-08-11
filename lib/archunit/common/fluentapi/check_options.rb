# frozen_string_literal: true

require_relative '../logging/logging_options'

module ArchUnit
  module Common
    module FluentApi
      # Immutable options shared by every terminal rule check.
      CheckOptions = Data.define(:allow_empty_tests, :logging, :clear_cache) do
        def self.resolve(value)
          return new if value.nil?
          return value if value.is_a?(self)

          raise ArgumentError, 'options must be a CheckOptions value or nil'
        end

        def initialize(allow_empty_tests: false, logging: nil, clear_cache: false)
          validate_boolean(allow_empty_tests, :allow_empty_tests)
          validate_logging(logging)
          validate_boolean(clear_cache, :clear_cache)
          super
        end

        def allow_empty_tests?
          allow_empty_tests
        end

        def clear_cache?
          clear_cache
        end

        private

        def validate_boolean(value, attribute)
          return if [true, false].include?(value)

          raise ArgumentError, "#{attribute} must be true or false"
        end

        def validate_logging(value)
          return if value.nil? || value.is_a?(Logging::LoggingOptions)

          raise ArgumentError, 'logging must be a LoggingOptions value or nil'
        end
      end
    end
  end
end
