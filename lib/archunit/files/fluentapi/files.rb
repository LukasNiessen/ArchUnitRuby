# frozen_string_literal: true

require_relative 'file_condition_builder'
require_relative 'positive_match_pattern_file_condition_builder'
require_relative 'negated_match_pattern_file_condition_builder'

# Public ArchUnitRuby entry points for file rules.
module ArchUnit
  module Files
    # Sentence-like entry points and builders for file architecture rules.
    module FluentApi
      module_function

      # Starts an immutable file-rule sentence.
      # @param project_locator [String, Pathname, nil] project directory, Gemfile, or gemspec
      # @return [FileConditionBuilder]
      def project_files(project_locator = nil)
        FileConditionBuilder.new(project_locator:)
      end

      class << self
        alias files project_files
      end
    end
  end

  # Starts an immutable file-rule sentence.
  # @param project_locator [String, Pathname, nil] project directory, Gemfile, or gemspec
  # @return [Files::FluentApi::FileConditionBuilder]
  def self.project_files(project_locator = nil)
    Files::FluentApi.project_files(project_locator)
  end

  class << self
    alias files project_files
  end
end
