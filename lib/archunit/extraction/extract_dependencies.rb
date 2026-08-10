# frozen_string_literal: true

require 'pathname'
require_relative '../common/extraction/edge'
require_relative 'enumerate_source_files'
require_relative 'extract_imports'

module ArchUnit
  # Turns statically resolvable Ruby imports into dependency edges.
  module Extraction
    module_function

    def extract_dependencies(project_root, exclude_patterns: nil)
      source_files = enumerate_source_files(project_root, exclude_patterns:)
      root = Pathname.new(path_value(project_root)).expand_path.realpath
      extract_dependencies_from(root, source_files)
    end

    def extract_dependencies_from(root, source_files)
      internal_targets = internal_target_index(root, source_files)

      source_files.flat_map do |source|
        extract_imports(root.join(source), project_root: root).map do |import|
          dependency_edge(source, import, internal_targets)
        end
      end.freeze
    end
    private_class_method :extract_dependencies_from

    def path_value(value)
      value.respond_to?(:to_path) ? value.to_path : value
    end
    private_class_method :path_value

    def internal_target_index(root, source_files)
      source_files.to_h do |identifier|
        [canonical_path(root.join(identifier)), identifier]
      end
    end
    private_class_method :internal_target_index

    def dependency_edge(source, import, internal_targets)
      target = import.resolved_path && internal_targets[canonical_path(import.resolved_path)]

      Common::Extraction::Edge.new(
        source: source,
        target: target || import.module_name,
        external: target.nil?,
        import_kinds: [import.import_kind]
      )
    end
    private_class_method :dependency_edge

    def canonical_path(path)
      Pathname.new(path).realpath.to_s.tr('\\', '/')
    rescue SystemCallError
      Pathname.new(path).expand_path.to_s.tr('\\', '/')
    end
    private_class_method :canonical_path
  end
end
