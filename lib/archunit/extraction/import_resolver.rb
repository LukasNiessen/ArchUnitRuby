# frozen_string_literal: true

require_relative '../common/extraction/import_kind'
require_relative 'extraction_profile'
require_relative 'resolve_import'

module ArchUnit
  module Extraction
    # Resolves one source file's imports and reuses context-independent feature lookups.
    class ImportResolver
      def initialize(source_path:, project_root:, load_paths:, profile: nil, cache: nil)
        @source_path = source_path
        @project_root = project_root
        @load_paths = load_paths
        @profile = profile
        @cache = cache
      end

      def resolve(module_name, import_kind)
        key = cache_key(module_name, import_kind)
        return cached_resolution(key) if @cache&.key?(key)

        @profile&.increment(:resolution_cache_misses) if @cache
        resolution = uncached_resolution(module_name, import_kind)
        @cache[key] = resolution if @cache
        resolution
      end

      private

      def cached_resolution(key)
        @profile&.increment(:resolution_cache_hits)
        @cache[key]
      end

      def uncached_resolution(module_name, import_kind)
        ExtractionProfile.measure(@profile, :target_resolution) do
          Extraction.resolve_import(
            module_name,
            source_file: @source_path,
            project_root: @project_root,
            import_kind:,
            load_paths: @load_paths
          )
        end
      end

      def cache_key(module_name, import_kind)
        source_context = if import_kind == Common::Extraction::ImportKind::REQUIRE_RELATIVE
                           File.dirname(@source_path.to_s)
                         end
        [module_name, import_kind, source_context].freeze
      end
    end
  end
end
