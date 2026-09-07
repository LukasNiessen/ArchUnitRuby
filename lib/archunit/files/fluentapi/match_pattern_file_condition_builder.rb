# frozen_string_literal: true

require_relative '../../common/regex_factory'
require_relative 'custom_file_condition'
require_relative 'depend_on_external_module_condition_builder'
require_relative 'depend_on_file_condition_builder'
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

        # Requires selected files to match a basename pattern.
        # @return [MatchPatternFileCondition]
        def have_name(pattern, except: nil)
          matching(Common::RegexFactory.filename_matcher(pattern, except:))
        end

        # Requires selected files to match a containing-folder pattern.
        # @return [MatchPatternFileCondition]
        def be_in_folder(pattern, except: nil)
          matching(Common::RegexFactory.folder_matcher(pattern, except:))
        end

        # Requires selected files to match a complete-path pattern.
        # @return [MatchPatternFileCondition]
        def be_in_path(pattern, except: nil)
          matching(Common::RegexFactory.path_matcher(pattern, except:))
        end

        # Starts the object stage for internal file dependencies.
        # @return [DependOnFileConditionBuilder]
        def depend_on_files
          DependOnFileConditionBuilder.new(self)
        end

        # Starts the object stage for standard-library and gem imports.
        # @return [DependOnExternalModuleConditionBuilder]
        def depend_on_external_modules
          DependOnExternalModuleConditionBuilder.new(self)
        end

        # Applies a custom predicate to each selected FileInfo.
        # @param condition [#call] predicate receiving one FileInfo
        # @param message [String] explanation used for violations
        # @return [CustomFileCondition]
        def adhere_to(condition, message)
          CustomFileCondition.new(self, condition:, message:)
        end

        private

        def matching(check_filter)
          MatchPatternFileCondition.new(self, check_filter:)
        end
      end
    end
  end
end
