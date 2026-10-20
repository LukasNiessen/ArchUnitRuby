# frozen_string_literal: true

module ArchUnit
  module Extraction
    # Keeps local-string inference inside straight-line code and lexical scopes.
    module ConservativeLocalFlow
      def visit_def_node(node)
        @local_strings.isolated_scope { super }
      end

      def visit_class_node(node)
        @local_strings.isolated_scope { super }
      end

      def visit_module_node(node)
        @local_strings.isolated_scope { super }
      end

      def visit_singleton_class_node(node)
        @local_strings.isolated_scope { super }
      end

      def visit_block_node(node)
        @local_strings.isolated_scope { super }
        @local_strings.capture_scopes
      end

      def visit_lambda_node(node)
        @local_strings.isolated_scope { super }
        @local_strings.capture_scopes
      end

      def visit_local_variable_operator_write_node(node)
        super
        @local_strings.assign(node.name, nil)
      end

      def visit_local_variable_or_write_node(node)
        super
        @local_strings.assign(node.name, nil)
      end

      def visit_local_variable_and_write_node(node)
        super
        @local_strings.assign(node.name, nil)
      end

      def visit_multi_write_node(node)
        super
        @local_strings.invalidate_all
      end

      def visit_post_execution_node(node)
        @local_strings.uncertain_flow { super }
        @local_strings.capture_scopes
      end

      def visit_match_write_node(node)
        super
        @local_strings.invalidate_all
      end

      def visit_instance_variable_write_node(node)
        super
        @local_strings.invalidate_escaped(node.value)
      end

      def visit_global_variable_write_node(node)
        super
        @local_strings.invalidate_escaped(node.value)
      end

      def visit_class_variable_write_node(node)
        super
        @local_strings.invalidate_escaped(node.value)
      end

      def visit_constant_write_node(node)
        super
        @local_strings.invalidate_escaped(node.value)
      end

      def visit_constant_path_write_node(node)
        super
        @local_strings.invalidate_escaped(node.value)
      end

      # These constructs require control-flow analysis beyond the supported straight-line subset.
      %i[
        begin defined pre_execution if unless and or case case_match while until for
        rescue rescue_modifier
      ].each do |kind|
        define_method("visit_#{kind}_node") do |node|
          @local_strings.uncertain_flow { super(node) }
        end
      end
    end
    private_constant :ConservativeLocalFlow
  end
end
