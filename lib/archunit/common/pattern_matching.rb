# frozen_string_literal: true

require_relative 'filter'

module ArchUnit
  module Common
    # Generic matching operations. The Filter selects which part of a candidate is tested.
    module PatternMatching
      module_function

      def matches_pattern?(file_path, filter, class_name: nil)
        validate_arguments(file_path, filter, class_name)
        target = target_string(file_path, filter.target, class_name)
        matches = regexp_matches?(filter, target)

        matches && filter.exclusions.none? do |exclusion|
          matches_pattern?(file_path, exclusion, class_name:)
        end
      end

      def matches_all_patterns?(file_path, filters, class_name: nil)
        filters.all? { |filter| matches_pattern?(file_path, filter, class_name:) }
      end

      def matches_any_pattern?(file_path, filters, class_name: nil)
        filters.any? { |filter| matches_pattern?(file_path, filter, class_name:) }
      end

      def normalize_path(path)
        path.tr('\\', '/')
      end

      def extract_filename(path)
        normalize_path(path).split('/').last.to_s
      end

      def path_without_filename(path)
        parts = normalize_path(path).split('/')
        parts.pop
        parts.join('/')
      end

      def validate_arguments(file_path, filter, class_name)
        raise ArgumentError, 'file_path must be a String' unless file_path.is_a?(String)
        raise ArgumentError, 'filter must be a Filter' unless filter.is_a?(Filter)
        return if class_name.nil? || class_name.is_a?(String)

        raise ArgumentError, 'class_name must be a String'
      end
      private_class_method :validate_arguments

      def target_string(file_path, target, class_name)
        case target
        when :filename
          extract_filename(file_path)
        when :path
          normalize_path(file_path)
        when :path_without_filename
          path_without_filename(file_path)
        when :classname
          class_name || raise(ArgumentError, 'class_name is required for a classname filter')
        end
      end
      private_class_method :target_string

      def regexp_matches?(filter, target)
        match = filter.regexp.match(target)
        return false unless match
        return true if filter.matching == :partial

        match.begin(0).zero? && match.end(0) == target.length
      end
      private_class_method :regexp_matches?
    end
  end
end
