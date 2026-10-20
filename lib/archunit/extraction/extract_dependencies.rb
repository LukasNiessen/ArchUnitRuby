# frozen_string_literal: true

require 'pathname'
require_relative '../common/extraction/edge'
require_relative '../common/fluentapi/check_options'
require_relative 'enumerate_source_files'
require_relative 'extract_imports'
require_relative 'resolve_load_paths'
require_relative 'constant_index'

module ArchUnit
  # Turns statically resolvable Ruby imports into dependency edges.
  module Extraction
    DependencyContext = Data.define(
      :root, :targets, :load_paths, :profile, :cache, :include_evidence
    )
    private_constant :DependencyContext

    module_function

    def extract_dependencies(project_root, exclude_patterns: nil, options: nil)
      options = Common::FluentApi::CheckOptions.resolve(options)
      source_files = enumerate_source_files(project_root, exclude_patterns:)
      root = Pathname.new(path_value(project_root)).expand_path.realpath
      load_paths = LoadPaths.resolve(
        root, explicit_paths: options.load_paths, source_files:
      )
      extract_dependencies_from(root, source_files, load_paths:, options:)
    end

    def extract_dependencies_from(root, source_files, load_paths:, options:, profile: nil)
      context = DependencyContext.new(
        root:, targets: profiled_target_index(root, source_files, profile), load_paths:,
        profile:, cache: {}, include_evidence: options.constant_references?
      )

      analyses = options.constant_references? ? parse_sources(root, source_files, profile) : {}
      edges = source_files.flat_map do |source|
        dependencies_for_source(source, context, analyses[source])
      end
      edges.concat(constant_edges(analyses, profile)) if options.constant_references?
      edges.freeze
    end
    private_class_method :extract_dependencies_from

    def profiled_target_index(root, source_files, profile)
      ExtractionProfile.measure(profile, :target_index) do
        internal_target_index(root, source_files)
      end
    end
    private_class_method :profiled_target_index

    def parse_sources(root, sources, profile)
      sources.to_h { |source| [source, parse_source(root.join(source), profile)] }
    end
    private_class_method :parse_sources

    def constant_edges(analyses, profile)
      ExtractionProfile.measure(profile, :constant_indexing) do
        ConstantIndex.new(analyses, profile:).edges
      end
    end
    private_class_method :constant_edges

    def dependencies_for_source(source, context, parse_result)
      imports = extract_imports_from(
        context.root.join(source),
        project_root: context.root,
        load_paths: context.load_paths,
        profile: context.profile,
        resolution_cache: context.cache,
        parse_result:
      )
      context.profile&.increment(:imports, imports.length)
      classify_imports(source, imports, context)
    end
    private_class_method :dependencies_for_source

    def classify_imports(source, imports, context)
      ExtractionProfile.measure(context.profile, :edge_classification) do
        imports.map do |import|
          dependency_edge(
            source, import, context.targets, include_evidence: context.include_evidence
          )
        end
      end
    end
    private_class_method :classify_imports

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

    def dependency_edge(source, import, internal_targets, include_evidence:)
      target = import.resolved_path && internal_targets[canonical_path(import.resolved_path)]

      Common::Extraction::Edge.new(
        source: source,
        target: target || import.module_name,
        external: target.nil?,
        import_kinds: [import.import_kind],
        evidence: include_evidence ? [import_evidence(source, import)] : []
      )
    end
    private_class_method :dependency_edge

    def import_evidence(source, import)
      Common::Extraction::DependencyEvidence.new(
        source:, kind: import.import_kind, name: import.module_name,
        line_number: import.line_number, end_line: import.end_line
      )
    end
    private_class_method :import_evidence

    def canonical_path(path)
      normalized = Pathname.new(path).expand_path.cleanpath.to_s.tr('\\', '/')
      File::FNM_SYSCASE.zero? ? normalized : normalized.downcase
    end
    private_class_method :canonical_path
  end
end
