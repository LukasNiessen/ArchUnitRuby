# frozen_string_literal: true

require_relative '../extraction/edge'

module ArchUnit
  module Common
    module Projection
      # A graph node with its incoming and outgoing raw dependency edges.
      ProjectedNode = Data.define(:label, :incoming, :outgoing) do
        def initialize(label:, incoming: [], outgoing: [])
          label = immutable_label(label)
          incoming = immutable_edges(incoming, :incoming)
          outgoing = immutable_edges(outgoing, :outgoing)
          super
        end

        private

        def immutable_label(value)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'label must be a non-empty String'
        end

        def immutable_edges(values, attribute)
          edges = Array(values).dup
          unless edges.all?(Extraction::Edge)
            raise ArgumentError, "#{attribute} must contain only Edge values"
          end

          edges.freeze
        end
      end
    end
  end
end
