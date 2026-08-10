# frozen_string_literal: true

require_relative 'metric_info'

module ArchUnit
  module Metrics
    module Extraction
      # One source file enriched with project-level dependency coupling.
      DistanceInfo = Data.define(
        :file_info, :afferent_coupling, :efferent_coupling, :project_file_count
      ) do
        include ValueValidation

        def initialize(
          file_info:, afferent_coupling:, efferent_coupling:, project_file_count:
        )
          raise ArgumentError, 'file_info must be a FileInfo value' unless file_info.is_a?(FileInfo)

          project_file_count = positive_integer(project_file_count, :project_file_count)
          afferent_coupling = coupling_value(
            afferent_coupling, :afferent_coupling, project_file_count
          )
          efferent_coupling = coupling_value(
            efferent_coupling, :efferent_coupling, project_file_count
          )
          super
        end

        def identifier
          file_info.identifier
        end

        def path
          file_info.path
        end

        def type_count
          file_info.type_count
        end

        def abstract_type_count
          file_info.abstract_type_count
        end

        def lines_of_code
          file_info.lines_of_code
        end

        private

        def coupling_value(value, attribute, file_count)
          value = non_negative_integer(value, attribute)
          return value if value < file_count

          raise ArgumentError, "#{attribute} cannot exceed the other project files"
        end
      end
    end
  end
end
