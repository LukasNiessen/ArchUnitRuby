# frozen_string_literal: true

require_relative '../../common/filter'
require_relative '../../common/pattern_matching'
require_relative '../../common/regex_factory'
require_relative '../extraction/extract_project_info'
require_relative 'count_metrics_builder'
require_relative 'lcom_metrics_builder'

module ArchUnit
  module Metrics
    module FluentApi
      # Immutable scope builder for numeric metrics over Ruby source.
      class MetricsBuilder
        attr_reader :project_locator, :filters

        def initialize(project_locator: nil, filters: [])
          @project_locator = immutable_project_locator(project_locator)
          @filters = immutable_filters(filters)
          freeze
        end

        def with_name(pattern)
          with_filter(Common::RegexFactory.filename_matcher(pattern))
        end

        def in_folder(pattern)
          with_filter(Common::RegexFactory.folder_matcher(pattern))
        end

        def in_path(pattern)
          with_filter(Common::RegexFactory.path_matcher(pattern))
        end

        def for_classes_matching(pattern)
          with_filter(Common::RegexFactory.classname_matcher(pattern))
        end

        def count
          CountMetricsBuilder.new(self)
        end

        def lcom
          LCOMMetricsBuilder.new(self)
        end

        def analyze
          project = Extraction.extract_project_info(project_locator)
          selected_files = project.files.select { |file| file_selected?(file) }
          Extraction::ProjectInfo.new(project_root: project.project_root, files: selected_files)
        end

        private

        def with_filter(filter)
          self.class.new(project_locator:, filters: [*filters, filter])
        end

        def subjects_for(subject_type)
          project = analyze
          return project.files if subject_type == Extraction::FileInfo
          if subject_type == Extraction::ClassInfo
            return project.classes.select { |class_info| class_selected?(class_info) }
          end

          raise ArgumentError, "unsupported metric subject type: #{subject_type}"
        end

        def file_selected?(file_info)
          path_filters, class_filters = filters.partition { |filter| filter.target != :classname }
          matches_path = Common::PatternMatching.matches_all_patterns?(file_info.path, path_filters)
          return false unless matches_path
          return true if class_filters.empty?

          file_info.class_infos.any? do |class_info|
            Common::PatternMatching.matches_all_patterns?(
              file_info.path, class_filters, class_name: class_info.name
            )
          end
        end

        def class_selected?(class_info)
          Common::PatternMatching.matches_all_patterns?(
            class_info.file_path, filters, class_name: class_info.name
          )
        end

        def immutable_project_locator(locator)
          return if locator.nil?

          locator = locator.to_path if locator.respond_to?(:to_path)
          unless locator.is_a?(String) && !locator.empty?
            raise ArgumentError, 'project_locator must be a non-empty path or nil'
          end

          locator.dup.freeze
        end

        def immutable_filters(values)
          filters = Array(values).dup
          unless filters.all?(Common::Filter)
            raise ArgumentError, 'filters must contain only Filter values'
          end

          filters.freeze
        end
      end
    end
  end
end
