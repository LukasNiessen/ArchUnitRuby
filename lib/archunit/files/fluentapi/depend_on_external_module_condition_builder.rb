# frozen_string_literal: true

require_relative '../../common/regex_factory'
require_relative 'depend_on_external_module_condition'

module ArchUnit
  module Files
    module FluentApi
      # Immutable object stage selecting external dependency names.
      class DependOnExternalModuleConditionBuilder
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

        def matching(module_name, except: nil)
          filter = Common::RegexFactory.path_matcher(module_name, except:)
          DependOnExternalModuleCondition.new(self, module_filters: [filter])
        end
      end
    end
  end
end
