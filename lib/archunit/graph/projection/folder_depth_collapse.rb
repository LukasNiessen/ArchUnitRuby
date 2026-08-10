# frozen_string_literal: true

module ArchUnit
  module GraphReporting
    module Projection
      # Collapse file nodes to their folder path at a fixed depth.
      FolderDepthCollapse = Data.define(:depth) do
        def initialize(depth:)
          unless depth.is_a?(Integer) && depth.positive?
            raise ArgumentError, 'depth must be a positive Integer'
          end

          super
        end
      end
    end
  end
end
