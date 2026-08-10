# frozen_string_literal: true

require_relative '../../common/regex_factory'
require_relative 'match_pattern_file_condition'

module ArchUnit
  module Files
    module FluentApi
      # Shared immutable state for positive and negated file predicate builders.
      class MatchPatternFileConditionBuilder
        attr_reader :project_locator, :filters

        def initialize(scope, negated:)
          unless scope.is_a?(FileConditionBuilder)
            raise ArgumentError, 'scope must be a FileConditionBuilder'
          end
          unless [true, false].include?(negated)
            raise ArgumentError, 'negated must be true or false'
          end

          @project_locator = scope.project_locator
          @filters = scope.filters
          @negated = negated
          freeze
        end

        def negated?
          @negated
        end

        def have_name(pattern)
          matching(Common::RegexFactory.filename_matcher(pattern))
        end

        def be_in_folder(pattern)
          matching(Common::RegexFactory.folder_matcher(pattern))
        end

        def be_in_path(pattern)
          matching(Common::RegexFactory.path_matcher(pattern))
        end

        private

        def matching(check_filter)
          MatchPatternFileCondition.new(self, check_filter:)
        end
      end
    end
  end
end
