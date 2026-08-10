# frozen_string_literal: true

require_relative '../../common/extraction/import_kind'

module ArchUnit
  module GraphReporting
    module Projection
      # Aggregated dependency evidence in a graph report snapshot.
      GraphReportEdge = Data.define(:source, :target, :count, :external, :import_kinds) do
        def initialize(source:, target:, count:, external:, import_kinds: [])
          source = immutable_string(source, :source)
          target = immutable_string(target, :target)
          validate_count(count)
          validate_external(external)
          import_kinds = immutable_import_kinds(import_kinds)
          super
        end

        private

        def immutable_string(value, attribute)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, "#{attribute} must be a non-empty String"
        end

        def validate_count(value)
          return if value.is_a?(Integer) && value.positive?

          raise ArgumentError, 'count must be a positive Integer'
        end

        def validate_external(value)
          return if [true, false].include?(value)

          raise ArgumentError, 'external must be true or false'
        end

        def immutable_import_kinds(values)
          kinds = Array(values).uniq.sort_by(&:to_s)
          unless kinds.all? { |kind| Common::Extraction::ImportKind.valid?(kind) }
            raise ArgumentError, 'import_kinds contains an unknown import kind'
          end

          kinds.freeze
        end
      end
    end
  end
end
