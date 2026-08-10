# frozen_string_literal: true

require 'prism'
require_relative 'metric_info'

module ArchUnit
  module Metrics
    module Extraction
      # Collects Ruby-specific count and class-cohesion facts from a Prism tree.
      # rubocop:disable Metrics/ClassLength -- One visitor owns the state of a single AST walk.
      class SourceMetricsVisitor < Prism::Visitor
        IMPORT_METHODS = %i[autoload load require require_relative].freeze
        ATTRIBUTE_METHODS = %i[attr_accessor attr_reader attr_writer].freeze
        INSTANCE_VARIABLE_NODES = %i[
          visit_instance_variable_and_write_node
          visit_instance_variable_operator_write_node
          visit_instance_variable_or_write_node
          visit_instance_variable_read_node
          visit_instance_variable_target_node
          visit_instance_variable_write_node
        ].freeze

        attr_reader :class_infos, :statement_count, :import_count, :class_count, :function_count

        def initialize(file_path)
          super()
          @file_path = file_path
          @class_infos = []
          reset_context
          reset_counts
        end

        def reset_context
          @class_stack = []
          @method_stack = []
          @namespace_stack = []
          @singleton_class_depth = 0
        end
        private :reset_context

        def reset_counts
          @statement_count = 0
          @import_count = 0
          @class_count = 0
          @function_count = 0
        end
        private :reset_counts

        def visit_statements_node(node)
          @statement_count += node.body.length
          super
        end

        def visit_call_node(node)
          @import_count += 1 if import_call?(node)
          record_attribute_methods(node)
          super
        end

        def visit_class_node(node)
          @class_count += 1
          with_class(qualified_name(node.constant_path)) { super }
        end

        def visit_module_node(node)
          with_namespace(qualified_name(node.constant_path)) { super }
        end

        def visit_singleton_class_node(node)
          @singleton_class_depth += 1
          super
        ensure
          @singleton_class_depth -= 1
        end

        # rubocop:disable Metrics/MethodLength -- The ensure keeps nested visitor state balanced.
        def visit_def_node(node)
          active_class = active_class_accumulator
          unless active_class
            @function_count += 1 if current_namespace.nil?
            return super
          end

          method_name = qualified_method_name(node)
          method = active_class[:methods][method_name] ||= Set.new
          @method_stack << [active_class, method]
          super
        ensure
          @method_stack.pop if active_class
        end
        # rubocop:enable Metrics/MethodLength

        INSTANCE_VARIABLE_NODES.each do |visitor_method|
          define_method(visitor_method) do |node|
            record_field_access(node.name)
            super(node)
          end
        end

        private

        def with_class(name)
          accumulator = { name:, methods: Hash.new { |hash, key| hash[key] = Set.new } }
          @class_stack << [name, accumulator]
          @namespace_stack << name
          yield
          @class_infos << build_class_info(accumulator)
        ensure
          @namespace_stack.pop
          @class_stack.pop
        end

        def with_namespace(name)
          @namespace_stack << name
          yield
        ensure
          @namespace_stack.pop
        end

        def current_namespace
          @namespace_stack.last
        end

        def qualified_method_name(node)
          return "self.#{node.name}" if node.receiver || @singleton_class_depth.positive?

          node.name.to_s
        end

        def active_class_accumulator
          namespace, accumulator = @class_stack.last
          accumulator if namespace == current_namespace
        end

        def qualified_name(constant_path)
          name = if constant_path.respond_to?(:full_name)
                   constant_path.full_name
                 else
                   constant_path.location.slice
                 end
          name = name.delete_prefix('::')
          return name if name.include?('::') || current_namespace.nil?

          "#{current_namespace}::#{name}"
        end

        def import_call?(node)
          return false unless IMPORT_METHODS.include?(node.name)
          return false unless supported_import_receiver?(node)

          arguments = node.arguments&.arguments || []
          expected_count = node.name == :autoload ? 2 : 1
          arguments.length == expected_count
        end

        def supported_import_receiver?(node)
          return true if node.receiver.nil?
          return constant_receiver?(node.receiver) if node.name == :autoload

          node.receiver.respond_to?(:full_name) &&
            node.receiver.full_name.delete_prefix('::') == 'Kernel'
        end

        def constant_receiver?(receiver)
          receiver.is_a?(Prism::ConstantReadNode) || receiver.is_a?(Prism::ConstantPathNode)
        end

        def record_attribute_methods(node)
          accumulator = active_class_accumulator
          return unless accumulator && @method_stack.empty?
          return unless ATTRIBUTE_METHODS.include?(node.name)

          attribute_names(node).each do |field_name|
            add_attribute_reader(accumulator, field_name) unless node.name == :attr_writer
            add_attribute_writer(accumulator, field_name) unless node.name == :attr_reader
          end
        end

        def attribute_names(node)
          (node.arguments&.arguments || []).filter_map do |argument|
            supported = argument.is_a?(Prism::SymbolNode) ||
                        argument.is_a?(Prism::StringNode)
            argument.unescaped.to_s if supported
          end
        end

        def add_attribute_reader(accumulator, field_name)
          accumulator[:methods][field_name] << field_name
        end

        def add_attribute_writer(accumulator, field_name)
          accumulator[:methods]["#{field_name}="] << field_name
        end

        def record_field_access(variable_name)
          accumulator, method = @method_stack.last
          return if accumulator.nil? || !accumulator.equal?(active_class_accumulator)

          method << variable_name.to_s.delete_prefix('@')
        end

        def build_class_info(accumulator)
          methods = build_method_infos(accumulator)
          fields = build_field_infos(methods)
          ClassInfo.new(name: accumulator[:name], file_path: @file_path, methods:, fields:)
        end

        def build_method_infos(accumulator)
          accumulator[:methods].sort.map do |name, fields|
            MethodInfo.new(name:, accessed_fields: fields.to_a)
          end
        end

        def build_field_infos(methods)
          field_accesses = Hash.new { |hash, key| hash[key] = [] }
          methods.each do |method|
            method.accessed_fields.each { |field| field_accesses[field] << method.name }
          end
          field_accesses.sort.map do |name, method_names|
            FieldInfo.new(name:, accessed_by: method_names)
          end
        end
      end
      # rubocop:enable Metrics/ClassLength
      private_constant :SourceMetricsVisitor
    end
  end
end
