# frozen_string_literal: true

require 'prism'

module ArchUnit
  module Extraction
    # Collects declarations and uses with Ruby's lexical (not textual path) nesting.
    class ConstantVisitor < Prism::Visitor
      Definition = Data.define(:name, :line_number)
      Reference = Data.define(:name, :nesting, :inherited_scope, :line_number, :end_line)

      attr_reader :definitions, :references, :inherited_namespaces

      def initialize(namespace_names: nil)
        super()
        @namespace_names = namespace_names
        @definitions = []
        @references = []
        @nesting = []
        @inherited_namespaces = []
      end

      def visit_class_node(node)
        visit(node.superclass)
        visit_namespace(node, inherited: !node.superclass.nil?)
      end

      def visit_module_node(node)
        visit_namespace(node, inherited: false)
      end

      def visit_constant_write_node(node)
        define_constant(qualify(node.name.to_s), node)
        visit(node.value)
      end

      def visit_constant_path_write_node(node)
        name = static_name(node.target)
        define_constant(declaration_name(name), node) if name
        visit(node.value)
      end

      def visit_constant_read_node(node)
        record_reference(node.name.to_s, node)
      end

      def visit_constant_path_node(node)
        name = static_name(node)
        name ? record_reference(name, node) : super
      end

      def visit_call_node(node)
        if %i[include prepend extend const_set remove_const autoload].include?(node.name) &&
           !@nesting.empty?
          @inherited_namespaces << @nesting.first
        end
        super
      end

      def visit_singleton_class_node(node)
        visit(node.expression)
        previous = @dynamic_scope
        @dynamic_scope = true
        visit(node.body)
      ensure
        @dynamic_scope = previous
      end

      private

      def visit_namespace(node, inherited:)
        name = static_name(node.constant_path)
        return unless name

        full_name = declaration_name(name)
        define_constant(full_name, node.constant_path)
        @inherited_namespaces << full_name if inherited
        previous = @nesting
        @nesting = [full_name, *previous]
        visit(node.body)
      ensure
        @nesting = previous if previous
      end

      def declaration_name(name)
        return name.delete_prefix('::') if name.start_with?('::') || @nesting.empty?
        return qualify(name) unless name.include?('::')

        head = name.split('::').first
        owner = @nesting.find { |scope| @namespace_names&.include?("#{scope}::#{head}") }
        owner ? "#{owner}::#{name}" : name
      end

      def qualify(name)
        @nesting.empty? ? name : "#{@nesting.first}::#{name}"
      end

      def define_constant(name, node)
        return if @dynamic_scope

        @definitions << Definition.new(name:, line_number: node.location.start_line)
      end

      def record_reference(name, node)
        return if @dynamic_scope && !name.start_with?('::')

        @references << Reference.new(
          name:, nesting: @nesting.dup.freeze, inherited_scope: @nesting.first,
          line_number: node.location.start_line, end_line: node.location.end_line
        )
      end

      def static_name(node)
        return node.name.to_s if node.is_a?(Prism::ConstantReadNode)
        return unless node.is_a?(Prism::ConstantPathNode)
        return "::#{node.name}" if node.parent.nil?

        parent = static_name(node.parent)
        "#{parent}::#{node.name}" if parent
      end
    end
    private_constant :ConstantVisitor
  end
end
