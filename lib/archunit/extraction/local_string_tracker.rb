# frozen_string_literal: true

require 'prism'

module ArchUnit
  module Extraction
    # Conservatively tracks local variables whose current value is a literal String.
    class LocalStringTracker
      UNKNOWN = Object.new.freeze
      private_constant :UNKNOWN

      def initialize
        @scopes = [{}]
        @captured_scopes = [false]
        @uncertain_depth = 0
      end

      def resolve(node)
        return node.unescaped if node.is_a?(Prism::StringNode)
        return UNKNOWN if @uncertain_depth.positive? || @captured_scopes.last
        return scope.fetch(node.name, UNKNOWN) if node.is_a?(Prism::LocalVariableReadNode)

        UNKNOWN
      end

      def assign(name, value)
        invalidate_escaped(value) if value && !value.is_a?(Prism::StringNode)
        scope[name] = resolve(value)
      end

      def invalidate_escaped(node)
        local_reads(node).each { |name| scope[name] = UNKNOWN if scope.key?(name) }
      end

      def isolated_scope
        @scopes << {}
        @captured_scopes << false
        yield
      ensure
        @scopes.pop
        @captured_scopes.pop
      end

      def invalidate_all
        @scopes.each { |values| values.transform_values! { UNKNOWN } }
      end

      def capture_scopes
        @captured_scopes.map! { true }
        invalidate_all
      end

      def uncertain_flow
        invalidate_scope
        @uncertain_depth += 1
        yield
      ensure
        @uncertain_depth -= 1
        invalidate_scope
      end

      private

      def local_reads(node)
        return [node.name] if node.is_a?(Prism::LocalVariableReadNode)

        node.compact_child_nodes.flat_map { |child| local_reads(child) }.uniq
      end

      def invalidate_scope
        scope.transform_values! { UNKNOWN }
      end

      def scope
        @scopes.last
      end
    end
    private_constant :LocalStringTracker
  end
end
