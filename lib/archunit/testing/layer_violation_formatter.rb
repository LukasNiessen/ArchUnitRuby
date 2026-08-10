# frozen_string_literal: true

module ArchUnit
  module Testing
    # Human-readable presentation for structured layer violations.
    module LayerViolationFormatter
      private

      def layer_dependency(violation)
        edge = violation.dependency
        TestViolation.new(
          message: 'Layer dependency violation',
          details: "Layer '#{violation.source_layer}' #{layer_relationship(violation)} " \
                   "'#{violation.target_layer}' via '#{edge.source_label}' -> " \
                   "'#{edge.target_label}'."
        )
      end

      def layer_relationship(violation)
        return 'depends on forbidden layer' if violation.rule == :may_not_depend_on_layers

        'depends on layer outside its allowlist'
      end
    end
  end
end
