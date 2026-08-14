# frozen_string_literal: true

require 'prism'
require_relative '../common/extraction/import_kind'

module ArchUnit
  module Extraction
    # Collects supported literal dependency calls from a Prism syntax tree.
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
  end
end
