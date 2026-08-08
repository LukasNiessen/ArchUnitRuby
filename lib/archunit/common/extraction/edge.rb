# frozen_string_literal: true

require_relative 'import_kind'

module ArchUnit
  module Common
    module Extraction
      Edge = Data.define(:source, :target, :external, :import_kinds) do
        def initialize(source:, target:, external:, import_kinds: [])
          source = immutable_identifier(source, :source)
          target = immutable_identifier(target, :target)
          validate_external(external)
          import_kinds = immutable_import_kinds(import_kinds)

          super
        end

        private

        def immutable_identifier(value, attribute)
          unless value.is_a?(String) && !value.empty?
            raise ArgumentError, "#{attribute} must be a non-empty String"
          end

          value.dup.freeze
        end

        def validate_external(value)
          return if [true, false].include?(value)

          raise ArgumentError, 'external must be true or false'
        end

        def immutable_import_kinds(values)
          kinds = Array(values).uniq
          invalid_kinds = kinds.reject { |kind| ImportKind.valid?(kind) }
          unless invalid_kinds.empty?
            raise ArgumentError, "unknown import kinds: #{invalid_kinds.map(&:inspect).join(', ')}"
          end

          kinds.freeze
        end
      end
    end
  end
end
