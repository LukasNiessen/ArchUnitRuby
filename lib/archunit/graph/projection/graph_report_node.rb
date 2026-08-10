# frozen_string_literal: true

module ArchUnit
  module GraphReporting
    module Projection
      # Stable node identity and display label in a graph report snapshot.
      GraphReportNode = Data.define(:id, :label) do
        def initialize(id:, label:)
          super(id: immutable_string(id, :id), label: immutable_string(label, :label))
        end

        private

        def immutable_string(value, attribute)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, "#{attribute} must be a non-empty String"
        end
      end
    end
  end
end
