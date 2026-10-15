# frozen_string_literal: true

require 'prism'
require_relative '../error/technical_error'
require_relative '../error/user_error'
require_relative 'extraction_profile'
require_relative 'import_resolver'
require_relative 'import_visitor'
require_relative 'resolved_import'
require_relative 'validate_extraction_paths'

module ArchUnit
  # Parses Ruby source without executing it and resolves literal imports.
  module Extraction
    IGNORE_DIRECTIVE = /\A#\s*archunit:\s*ignore(?:\s+(?<modules>.+?))?\s*\z/

    module_function

    def extract_imports(
      source_file, project_root:, load_paths: nil, profile: nil, resolution_cache: nil
    )
      source_path = ExtractionPaths.source_file(source_file)
      root = ExtractionPaths.project_root(project_root)
      extract_imports_from(
        source_path, project_root: root, load_paths:, profile:, resolution_cache:
      )
    rescue UserError
      raise
    rescue SystemCallError => e
      raise TechnicalError, "could not parse Ruby source file: #{e.message}"
    end

    # rubocop:disable Metrics/ParameterLists -- Share the parsed AST with constant analysis.
    def extract_imports_from(
      source_path, project_root:, load_paths: nil, profile: nil, resolution_cache: nil,
      parse_result: nil
    )
      resolver = build_import_resolver(
        source_path:, project_root:, load_paths:, profile:, cache: resolution_cache
      )
      parse_result ||= parse_source(source_path, profile)
      resolve_imports(parsed_imports(parse_result, profile), resolver)
    rescue SystemCallError => e
      raise TechnicalError, "could not parse Ruby source file: #{e.message}"
    end
    private_class_method :extract_imports_from
    # rubocop:enable Metrics/ParameterLists

    def build_import_resolver(**)
      ImportResolver.new(**)
    end
    private_class_method :build_import_resolver

    def resolve_imports(imports, resolver)
      imports.map { |import| resolved_import(import, resolver) }.freeze
    end
    private_class_method :resolve_imports

    def parse_source(source_path, profile)
      source = ExtractionProfile.measure(profile, :file_read) { File.binread(source_path) }
      ExtractionProfile.measure(profile, :prism_parse) do
        Prism.parse(source, filepath: source_path.to_s)
      end
    rescue SystemCallError => e
      raise TechnicalError, "could not parse Ruby source file: #{e.message}"
    end
    private_class_method :parse_source

    def parsed_imports(parse_result, profile)
      return [] unless parse_result.success?

      ExtractionProfile.measure(profile, :import_extraction) do
        visitor = ImportVisitor.new
        visitor.visit(parse_result.value)
        profile&.increment(:unresolved_imports, visitor.unresolved_imports)
        reject_ignored_imports(visitor.imports, parse_result.comments)
      end
    end
    private_class_method :parsed_imports

    def reject_ignored_imports(imports, comments)
      directives = ignore_directives(comments)
      imports.reject do |module_name, _import_kind, start_line, end_line|
        directives.any? do |line, trailing, modules|
          directive_applies?(line, trailing, start_line, end_line) &&
            (modules.empty? || modules.any? { |name| ignored_module?(module_name, name) })
        end
      end
    end
    private_class_method :reject_ignored_imports

    def ignore_directives(comments)
      comments.filter_map do |comment|
        match = IGNORE_DIRECTIVE.match(comment.location.slice)
        next unless match

        [comment.location.start_line, comment.trailing?, directive_modules(match[:modules])]
      end
    end
    private_class_method :ignore_directives

    def directive_applies?(line, trailing, start_line, end_line)
      return line.between?(start_line, end_line) if trailing

      start_line == line + 1
    end
    private_class_method :directive_applies?

    def directive_modules(value)
      return [] if value.nil?

      value.split(/[\s,]+/).reject(&:empty?)
    end
    private_class_method :directive_modules

    def ignored_module?(module_name, scoped_name)
      module_name == scoped_name || module_name.start_with?("#{scoped_name}/")
    end
    private_class_method :ignored_module?

    def resolved_import(located_import, resolver)
      module_name, import_kind, line_number, end_line = located_import
      ResolvedImport.new(
        module_name: module_name,
        import_kind: import_kind,
        line_number: line_number,
        end_line: end_line,
        resolved_path: resolver.resolve(module_name, import_kind)
      )
    end
    private_class_method :resolved_import
  end
end
