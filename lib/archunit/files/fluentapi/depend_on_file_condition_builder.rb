# frozen_string_literal: true

require_relative '../../common/regex_factory'
require_relative 'depend_on_file_condition'

module ArchUnit
  module Files
    module FluentApi
      # Immutable object stage selecting internal dependency targets.
      class DependOnFileConditionBuilder
        attr_reader :mood, :project_locator, :subject_filters, :is_negated

        def initialize(mood)
          unless mood.is_a?(MatchPatternFileConditionBuilder)
            raise ArgumentError, 'mood must be a file condition builder'
          end

          @mood = mood
          @project_locator = mood.project_locator
          @subject_filters = mood.filters
          @is_negated = mood.negated?
          freeze
        end

        def negated?
          is_negated
        end

        def with_name(pattern)
          condition(Common::RegexFactory.filename_matcher(pattern))
        end

        def in_folder(pattern)
          condition(Common::RegexFactory.folder_matcher(pattern))
        end

        def in_path(pattern)
          condition(Common::RegexFactory.path_matcher(pattern))
        end

        private

        def condition(filter)
          DependOnFileCondition.new(self, object_filters: [filter])
        end
      end
    end
  end
end
