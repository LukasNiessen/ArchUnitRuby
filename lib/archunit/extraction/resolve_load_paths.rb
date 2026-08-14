# frozen_string_literal: true

require 'pathname'
require_relative '../error/user_error'
require_relative 'discover_gemspec_load_paths'

module ArchUnit
  module Extraction
    # Builds the deterministic feature search path used for static Ruby import resolution.
    module LoadPaths
      module_function

      def resolve(project_root, explicit_paths: [], source_files: nil)
        root = canonical_root(project_root)
        defaults = [root.join('lib'), root].select(&:directory?)
        explicit = resolve_explicit_paths(root, explicit_paths)
        discovered = GemspecLoadPaths.resolve(root, source_files:)

        deduplicate(defaults + explicit + discovered)
      end

      def canonical_root(value)
        path = value.respond_to?(:to_path) ? value.to_path : value
        unless path.is_a?(String) && !path.empty?
          raise UserError, 'project_root must be a non-empty path'
        end

        root = Pathname.new(path).expand_path
        raise UserError, 'project_root must be an existing directory' unless root.directory?

        root.realpath
      end
      private_class_method :canonical_root

      def resolve_explicit_paths(root, paths)
        validate_explicit_paths(paths)
        paths.map { |value| resolve_explicit_path(root, value) }
      end
      private_class_method :resolve_explicit_paths

      def resolve_explicit_path(root, value)
        candidate = Pathname.new(value.tr('\\', '/'))
        candidate = root.join(candidate) unless candidate.absolute?
        candidate = candidate.expand_path
        validate_explicit_path(candidate, root, value)
        candidate.realpath
      end
      private_class_method :resolve_explicit_path

      def validate_explicit_path(candidate, root, value)
        unless candidate.directory?
          raise UserError, "load path must be an existing directory: #{value}"
        end

        canonical = candidate.realpath
        return if within_project?(canonical, root)

        raise UserError, "load path must stay inside the project root: #{value}"
      end
      private_class_method :validate_explicit_path

      def validate_explicit_paths(paths)
        valid = paths.is_a?(Array) && paths.all? do |path|
          path.is_a?(String) && !path.empty?
        end
        return if valid

        raise UserError, 'load_paths must be an Array of non-empty paths'
      end
      private_class_method :validate_explicit_paths

      def within_project?(path, root)
        path.relative_path_from(root).each_filename.first != '..'
      rescue ArgumentError
        false
      end
      private_class_method :within_project?

      def deduplicate(paths)
        paths.each_with_object([]) do |path, result|
          value = normalized(path).freeze
          result << value unless result.include?(value)
        end.freeze
      end
      private_class_method :deduplicate

      def normalized(path)
        path.to_s.tr('\\', '/')
      end
      private_class_method :normalized
    end
  end
end
