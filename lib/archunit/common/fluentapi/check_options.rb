# frozen_string_literal: true

require_relative '../logging/logging_options'

module ArchUnit
  module Common
    module FluentApi
      # Immutable options shared by every terminal rule check.
      CheckOptions = Data.define(
        :allow_empty_tests, :logging, :clear_cache, :load_paths, :dependency_analysis
      ) do
        def self.resolve(value)
          return new if value.nil?
          return value if value.is_a?(self)

          raise ArgumentError, 'options must be a CheckOptions value or nil'
        end

        def initialize(
          allow_empty_tests: false, logging: nil, clear_cache: false, load_paths: [],
          dependency_analysis: :imports
        )
          validate_boolean(allow_empty_tests, :allow_empty_tests)
          validate_logging(logging)
          validate_boolean(clear_cache, :clear_cache)
          load_paths = immutable_load_paths(load_paths)
          unless %i[imports imports_and_constants].include?(dependency_analysis)
            raise ArgumentError, 'dependency_analysis must be :imports or :imports_and_constants'
          end

          super
        end

        def allow_empty_tests?
          allow_empty_tests
        end

        def clear_cache?
          clear_cache
        end

        def constant_references?
          dependency_analysis == :imports_and_constants
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

        def immutable_load_paths(value)
          unless value.is_a?(Array)
            raise ArgumentError, 'load_paths must be an Array of non-empty paths'
          end

          value.map { |path| immutable_load_path(path) }.uniq.freeze
        end

        def immutable_load_path(value)
          value = value.to_path if value.respond_to?(:to_path)
          unless value.is_a?(String) && !value.empty?
            raise ArgumentError, 'load_paths must be an Array of non-empty paths'
          end

          value.tr('\\', '/').delete_suffix('/').freeze
        end
      end
    end
  end
end
