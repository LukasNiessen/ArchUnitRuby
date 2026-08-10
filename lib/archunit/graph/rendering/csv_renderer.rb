# frozen_string_literal: true

require 'csv'
require_relative 'rendering_support'

module ArchUnit
  module GraphReporting
    module Rendering
      # Renders aggregated graph edges as standards-compliant CSV.
      module CsvRenderer
        HEADERS = %w[source target count external import_kinds].freeze

        module_function

        def render(snapshot)
          snapshot = RenderingSupport.validate_snapshot(snapshot)
          CSV.generate(row_sep: "\n") do |csv|
            csv << HEADERS
            snapshot.edges.each do |edge|
              csv << [
                edge.source, edge.target, edge.count, edge.external,
                edge.import_kinds.join('|')
              ]
            end
          end.rstrip
        end
      end
    end
  end
end
