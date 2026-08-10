# frozen_string_literal: true

require 'pathname'
require 'prism'
require_relative '../error/technical_error'
require_relative '../error/user_error'
require_relative 'resolve_import'
require_relative 'resolved_import'

module ArchUnit
  # Parses Ruby source without executing it and resolves literal imports.
  module Extraction
    IGNORE_DIRECTIVE = /\A#\s*archunit:\s*ignore(?:\s+(?<modules>.+?))?\s*\z/

    # Collects supported dependency calls from a Prism syntax tree.
    class ImportVisitor < Prism::Visitor
      CALL_KINDS = {
        require: Common::Extraction::ImportKind::REQUIRE,
        require_relative: Common::Extraction::ImportKind::REQUIRE_RELATIVE,
        autoload: Common::Extraction::ImportKind::AUTOLOAD,
        load: Common::Extraction::ImportKind::LOAD
      }.freeze

      attr_reader :imports

      def initialize
        super
        @imports = []
      end

      def visit_call_node(node)
        record_import(node)
        super
      end

      private

      def record_import(node)
        import_kind = CALL_KINDS[node.name]
        return unless import_kind && supported_receiver?(node, import_kind)

        arguments = node.arguments&.arguments || []
        argument = import_argument(arguments, import_kind)
        return unless argument.is_a?(Prism::StringNode)
        return unless valid_module_name?(argument.unescaped)

        @imports << located_import(argument, import_kind, node)
      end

      def located_import(argument, import_kind, node)
        [argument.unescaped, import_kind, node.location.start_line, node.location.end_line]
      end

      def valid_module_name?(module_name)
        !module_name.empty? && !module_name.include?("\0")
      end

      def supported_receiver?(node, import_kind)
        return true if node.receiver.nil?
        if import_kind == Common::Extraction::ImportKind::AUTOLOAD
          return constant_receiver?(node.receiver)
        end

        node.receiver.respond_to?(:full_name) &&
          node.receiver.full_name.delete_prefix('::') == 'Kernel'
      end

      def constant_receiver?(receiver)
        receiver.is_a?(Prism::ConstantReadNode) || receiver.is_a?(Prism::ConstantPathNode)
      end

      def import_argument(arguments, import_kind)
        if import_kind == Common::Extraction::ImportKind::AUTOLOAD
          return unless arguments.length == 2

          arguments[1]
        else
          return unless arguments.length == 1

          arguments[0]
        end
      end
    end
    private_constant :ImportVisitor

    module_function

    def extract_imports(source_file, project_root:)
      source_path = import_source_path(source_file)
      root = import_project_root(project_root)
      parsed_imports(source_path).map do |located_import|
        resolved_import(located_import, source_path, root)
      end.freeze
    rescue UserError
      raise
    rescue SystemCallError => e
      raise TechnicalError, "could not parse Ruby source file: #{e.message}"
    end

    def parsed_imports(source_path)
      parse_result = Prism.parse_file(source_path.to_s)
      return [] unless parse_result.success?

      visitor = ImportVisitor.new
      visitor.visit(parse_result.value)
      reject_ignored_imports(visitor.imports, parse_result.comments)
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

    def resolved_import(located_import, source_path, root)
      module_name, import_kind, line_number, = located_import
      ResolvedImport.new(
        module_name: module_name,
        import_kind: import_kind,
        line_number: line_number,
        resolved_path: resolve_import_for(module_name, import_kind, source_path, root)
      )
    end
    private_class_method :resolved_import

    def resolve_import_for(module_name, import_kind, source_path, root)
      resolve_import(
        module_name,
        source_file: source_path,
        project_root: root,
        import_kind: import_kind
      )
    end
    private_class_method :resolve_import_for

    def import_source_path(value)
      path = extraction_path(value, 'source_file')
      raise UserError, 'source_file must be an existing file' unless path.file?

      path
    end
    private_class_method :import_source_path

    def import_project_root(value)
      path = extraction_path(value, 'project_root')
      raise UserError, 'project_root must be an existing directory' unless path.directory?

      path.realpath
    end
    private_class_method :import_project_root

    def extraction_path(value, attribute)
      value = value.to_path if value.respond_to?(:to_path)
      unless value.is_a?(String) && !value.empty?
        raise UserError, "#{attribute} must be a non-empty path"
      end

      Pathname.new(value).expand_path
    end
    private_class_method :extraction_path
  end
end
