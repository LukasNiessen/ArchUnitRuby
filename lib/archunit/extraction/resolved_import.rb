# frozen_string_literal: true

require_relative '../common/extraction/import_kind'

module ArchUnit
  module Extraction
    ResolvedImport = Data.define(:module_name, :import_kind, :line_number, :resolved_path) do
      def initialize(module_name:, import_kind:, line_number:, resolved_path: nil)
        validate_module_name(module_name)
        validate_import_kind(import_kind)
        validate_line_number(line_number)
        validate_resolved_path(resolved_path)

        module_name = module_name.dup.freeze
        resolved_path = resolved_path&.tr('\\', '/')&.freeze
        super
      end

      private

      def validate_module_name(value)
        return if value.is_a?(String) && !value.empty?

        raise ArgumentError, 'module_name must be a non-empty String'
      end

      def validate_import_kind(value)
        return if Common::Extraction::ImportKind.valid?(value)

        raise ArgumentError, "unknown import kind: #{value.inspect}"
      end

      def validate_line_number(value)
        return if value.is_a?(Integer) && value.positive?

        raise ArgumentError, 'line_number must be a positive Integer'
      end

      def validate_resolved_path(value)
        return if value.nil? || (value.is_a?(String) && !value.empty?)

        raise ArgumentError, 'resolved_path must be nil or a non-empty String'
      end
    end
  end
end
