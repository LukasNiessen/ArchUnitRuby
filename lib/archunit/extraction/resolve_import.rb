# frozen_string_literal: true

require 'pathname'
require_relative '../common/extraction/import_kind'

module ArchUnit
  # Resolves Ruby dependency names using Ruby's own feature resolver.
  module Extraction
    module_function

    def resolve_import(module_name, source_file:, project_root:, import_kind:)
      roots = import_search_roots(source_file, project_root, import_kind)
      resolved = if import_kind == Common::Extraction::ImportKind::LOAD
                   resolve_load(module_name, roots, import_kind)
                 else
                   resolve_feature(module_name, roots, import_kind)
                 end

      resolved&.tr('\\', '/')&.freeze
    end

    def import_search_roots(source_file, project_root, import_kind)
      if import_kind == Common::Extraction::ImportKind::REQUIRE_RELATIVE
        [File.dirname(File.expand_path(source_file))]
      else
        root = File.expand_path(project_root)
        [File.join(root, 'lib'), root]
      end
    end
    private_class_method :import_search_roots

    def resolve_feature(module_name, roots, import_kind)
      feature_candidates(module_name, roots).each do |candidate|
        resolution = $LOAD_PATH.resolve_feature_path(candidate)
        return resolution.last if resolution
      end

      return if import_kind == Common::Extraction::ImportKind::REQUIRE_RELATIVE

      $LOAD_PATH.resolve_feature_path(module_name)&.last
    end
    private_class_method :resolve_feature

    def resolve_load(module_name, roots, import_kind)
      load_candidates(module_name, roots).find { |candidate| File.file?(candidate) } ||
        resolve_load_from_global_path(module_name, import_kind)
    end
    private_class_method :resolve_load

    def resolve_load_from_global_path(module_name, import_kind)
      return if import_kind == Common::Extraction::ImportKind::REQUIRE_RELATIVE
      return if Pathname.new(module_name).absolute?

      $LOAD_PATH.lazy
                .map { |directory| File.expand_path(module_name, directory) }
                .find { |candidate| File.file?(candidate) }
    end
    private_class_method :resolve_load_from_global_path

    def feature_candidates(module_name, roots)
      path = Pathname.new(module_name)
      return [path.expand_path.to_s] if path.absolute?

      roots.map { |root| File.expand_path(module_name, root) }.uniq
    end
    private_class_method :feature_candidates

    def load_candidates(module_name, roots)
      path = Pathname.new(module_name)
      return [path.expand_path.to_s] if path.absolute?

      roots.map { |root| File.expand_path(module_name, root) }.uniq
    end
    private_class_method :load_candidates
  end
end
