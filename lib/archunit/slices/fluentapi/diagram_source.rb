# frozen_string_literal: true

module ArchUnit
  module Slices
    module FluentApi
      DIAGRAM_SOURCE_KINDS = %i[inline file].freeze

      # Immutable inline or file-backed PlantUML source, read only by a terminal check.
      DiagramSource = Data.define(:kind, :value) do
        def self.inline(text)
          new(kind: :inline, value: text)
        end

        def self.file(path)
          path = path.to_path if path.respond_to?(:to_path)
          new(kind: :file, value: path)
        end

        def initialize(kind:, value:)
          unless DIAGRAM_SOURCE_KINDS.include?(kind)
            raise ArgumentError, "kind must be one of: #{DIAGRAM_SOURCE_KINDS.join(', ')}"
          end
          unless value.is_a?(String) && !value.empty?
            raise ArgumentError, 'diagram source value must be a non-empty String'
          end

          super(kind:, value: value.dup.freeze)
        end

        def read
          kind == :inline ? value : File.read(value, encoding: Encoding::UTF_8)
        end
      end
    end
  end
end
