# frozen_string_literal: true

require_relative '../../common/assertion/violation'
require_relative '../extraction/file_info'

module ArchUnit
  module Files
    # Pure assertions over user-defined source-file predicates.
    module Assertion
      # Data describing a file that disagrees with a custom predicate.
      class CustomFileViolation < Common::Assertion::Violation
        attr_reader :file_info, :message, :is_negated

        def initialize(file_info:, message:, is_negated: false)
          @file_info = file_info_value(file_info)
          @message = message_value(message)
          @is_negated = boolean_value(is_negated)
          super()
        end

        def negated?
          is_negated
        end

        def ==(other)
          other.is_a?(self.class) &&
            file_info == other.file_info &&
            message == other.message &&
            is_negated == other.is_negated
        end
        alias eql? ==

        def hash
          [self.class, file_info, message, is_negated].hash
        end

        private

        def file_info_value(value)
          return value if value.is_a?(Files::Extraction::FileInfo)

          raise ArgumentError, 'file_info must be a FileInfo'
        end

        def message_value(value)
          return value.dup.freeze if value.is_a?(String) && !value.strip.empty?

          raise ArgumentError, 'message must be a non-empty String'
        end

        def boolean_value(value)
          return value if [true, false].include?(value)

          raise ArgumentError, 'is_negated must be true or false'
        end
      end

      module_function

      def gather_custom_file_violations(file_infos, condition, message, is_negated:)
        validate_custom_arguments(file_infos, condition, message, is_negated)

        file_infos.filter_map do |file_info|
          result = condition.call(file_info)
          unless [true, false].include?(result)
            raise ArgumentError, 'condition must return true or false'
          end
          next unless is_negated ? result : !result

          CustomFileViolation.new(file_info:, message:, is_negated:)
        end
      end

      def validate_custom_arguments(file_infos, condition, message, is_negated)
        unless file_infos.is_a?(Array) && file_infos.all?(Files::Extraction::FileInfo)
          raise ArgumentError, 'file_infos must be an Array of FileInfo values'
        end
        raise ArgumentError, 'condition must be callable' unless condition.respond_to?(:call)
        unless message.is_a?(String) && !message.strip.empty?
          raise ArgumentError, 'message must be a non-empty String'
        end
        return if [true, false].include?(is_negated)

        raise ArgumentError, 'is_negated must be true or false'
      end
      private_class_method :validate_custom_arguments
    end
  end
end
