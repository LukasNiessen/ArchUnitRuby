# frozen_string_literal: true

module ArchUnit
  module Common
    module Projection
      # The labels produced when a raw dependency edge is mapped into a domain view.
      MappedEdge = Data.define(:source_label, :target_label) do
        def initialize(source_label:, target_label:)
          source_label = immutable_label(source_label, :source_label)
          target_label = immutable_label(target_label, :target_label)
          super
        end

        private

        def immutable_label(value, attribute)
          unless value.is_a?(String) && !value.empty?
            raise ArgumentError, "#{attribute} must be a non-empty String"
          end

          value.dup.freeze
        end
      end
    end
  end
end
