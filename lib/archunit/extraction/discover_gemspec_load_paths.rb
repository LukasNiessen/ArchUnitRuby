# frozen_string_literal: true

require 'find'
require 'pathname'
require_relative 'enumerate_source_files'

module ArchUnit
  module Extraction
    # Discovers gem-adjacent lib directories without evaluating gemspecs.
    module GemspecLoadPaths
      module_function

      def resolve(root, source_files: nil)
        paths = if source_files
                  discover_from_sources(root, source_files)
                else
                  discover_with_walk(root)
                end
        paths.uniq.sort_by { |path| normalized(path) }
      end

      def discover_from_sources(root, source_files)
        roots = source_files.flat_map { |source| source_lib_roots(root, source) }.uniq
        roots.flat_map do |gem_root|
          gemspecs_in(gem_root).filter_map { |entry| gemspec_lib_path(entry, root) }
        end
      end
      private_class_method :discover_from_sources

      def source_lib_roots(root, source)
        segments = source.split('/')
        segments.each_index.filter_map do |index|
          next unless segments[index] == 'lib'

          index.zero? ? root : root.join(*segments.take(index))
        end
      end
      private_class_method :source_lib_roots

      def gemspecs_in(directory)
        directory.children.select do |entry|
          entry.file? && entry.extname == '.gemspec'
        end
      end
      private_class_method :gemspecs_in

      def discover_with_walk(root)
        paths = []
        Find.find(root.to_s) do |entry|
          next if directory_entry?(entry, root)

          lib = gemspec_lib_path(Pathname.new(entry), root)
          paths << lib if lib
        end
        paths
      end
      private_class_method :discover_with_walk

      def directory_entry?(entry, root)
        return false unless File.directory?(entry)

        Find.prune if entry != root.to_s && excluded_directory?(entry)
        true
      end
      private_class_method :directory_entry?

      def gemspec_lib_path(entry, root)
        return unless entry.extname == '.gemspec'

        lib = entry.dirname.join('lib')
        return unless lib.directory?

        canonical = lib.realpath
        canonical if within_project?(canonical, root)
      end
      private_class_method :gemspec_lib_path

      def excluded_directory?(path)
        Extraction::DEFAULT_EXCLUDED_DIRECTORIES.include?(File.basename(path))
      end
      private_class_method :excluded_directory?

      def within_project?(path, root)
        path.relative_path_from(root).each_filename.first != '..'
      rescue ArgumentError
        false
      end
      private_class_method :within_project?

      def normalized(path)
        path.to_s.tr('\\', '/')
      end
      private_class_method :normalized
    end
  end
end
