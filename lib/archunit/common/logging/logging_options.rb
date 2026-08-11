# frozen_string_literal: true

module ArchUnit
  module Common
    module Logging
      LOG_LEVELS = %i[debug info warn error].freeze
      private_constant :LOG_LEVELS

      # Immutable, per-check logging configuration. A nil CheckOptions#logging disables logging.
      LoggingOptions = Data.define(:level, :io, :output_directory, :append) do
        def initialize(level: :info, io: $stderr, output_directory: nil, append: false)
          level = normalize_level(level)
          validate_io(io)
          output_directory = normalize_output_directory(output_directory)
          validate_append(append)
          super
        end

        def file_output?
          !output_directory.nil?
        end

        private

        def normalize_level(value)
          normalized = value.respond_to?(:to_sym) ? value.to_sym : value
          return normalized if LOG_LEVELS.include?(normalized)

          raise ArgumentError, "level must be one of: #{LOG_LEVELS.join(', ')}"
        end

        def validate_io(value)
          return if value.nil? || value.respond_to?(:write)

          raise ArgumentError, 'io must respond to write or be nil'
        end

        def normalize_output_directory(value)
          return if value.nil?

          path = value.respond_to?(:to_path) ? value.to_path : value
          unless path.is_a?(String) && !path.empty?
            raise ArgumentError, 'output_directory must be a non-empty path or nil'
          end

          File.expand_path(path).freeze
        end

        def validate_append(value)
          return if [true, false].include?(value)

          raise ArgumentError, 'append must be true or false'
        end
      end
    end
  end
end
