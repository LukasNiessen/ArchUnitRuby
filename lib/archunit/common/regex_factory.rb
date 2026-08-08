# frozen_string_literal: true

require_relative 'filter'
require_relative 'pattern'

module ArchUnit
  module Common
    # The single construction point for user patterns and their matching targets.
    class RegexFactory
      class << self
        def filename_matcher(pattern)
          create_matcher(pattern, :filename)
        end

        def folder_matcher(pattern)
          create_matcher(pattern, :path_without_filename)
        end

        def path_matcher(pattern)
          create_matcher(pattern, :path)
        end

        def classname_matcher(pattern)
          create_matcher(pattern, :classname)
        end

        def exact_file_matcher(file_path)
          unless file_path.is_a?(String) && !file_path.empty?
            raise ArgumentError, 'file_path must be a non-empty String'
          end

          normalized_path = file_path.tr('\\', '/')
          regexp = Regexp.new("\\A#{Regexp.escape(normalized_path)}\\z")
          Filter.new(regexp:, target: :path, matching: :exact)
        end

        private

        def create_matcher(pattern, target)
          Filter.new(regexp: Pattern.compile(pattern), target:)
        end
      end

      private_class_method :new
    end
  end
end
