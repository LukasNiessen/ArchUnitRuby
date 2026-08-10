# frozen_string_literal: true

require_relative '../../common/filter'
require_relative '../../common/regex_factory'

module ArchUnit
  module Files
    module FluentApi
      # Immutable scope builder selecting the files to which a rule will apply.
      class FileConditionBuilder
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

        def in_file(file_path)
          with_filter(Common::RegexFactory.exact_file_matcher(file_path))
        end

        private

        def with_filter(filter)
          self.class.new(project_locator:, filters: [*filters, filter])
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
