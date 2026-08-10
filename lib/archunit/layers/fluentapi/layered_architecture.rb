# frozen_string_literal: true

require_relative '../../common/assertion/empty_test_violation'
require_relative '../../common/fluentapi/checkable'
require_relative '../../common/projection/edge_projections'
require_relative '../../common/projection/project_edges'
require_relative '../../common/projection/project_to_nodes'
require_relative '../../extraction/extract_graph'
require_relative '../assertion/layer_definition'
require_relative '../assertion/layer_dependencies'
require_relative 'layer_definition_builder'
require_relative 'layer_dependency_rule_builder'
require_relative 'layered_architecture_values'

module ArchUnit
  module Layers
    module FluentApi
      # Immutable, executable named-layer dependency policy.
      class LayeredArchitecture
        include Common::FluentApi::Checkable
        include LayeredArchitectureValues

        attr_reader :project_locator, :layer_definitions,
                    :allowed_dependencies, :forbidden_dependencies

        def initialize(
          project_locator: nil, layer_definitions: [],
          allowed_dependencies: {}, forbidden_dependencies: {}
        )
          @project_locator = immutable_project_locator(project_locator)
          @layer_definitions = immutable_layer_definitions(layer_definitions)
          @allowed_dependencies = immutable_dependency_map(allowed_dependencies)
          @forbidden_dependencies = immutable_dependency_map(forbidden_dependencies)
          freeze
        end

        def layer(name)
          LayerDefinitionBuilder.new(self, validated_layer_name(name))
        end

        def where_layer(name)
          name = validated_layer_name(name)
          ensure_defined_layer!(name)
          LayerDependencyRuleBuilder.new(self, name)
        end

        private

        def with_layer_filter(name, filter)
          definition = layer_definition(name)
          updated = if definition
                      replace_definition(definition, definition.with_filter(filter))
                    else
                      [*layer_definitions, Assertion::LayerDefinition.new(name:, filters: [filter])]
                    end
          copy(layer_definitions: updated)
        end

        def with_allowed_dependencies(source, targets)
          targets = validated_target_layers(targets)
          copy(allowed_dependencies: allowed_dependencies.merge(source => targets))
        end

        def with_forbidden_dependencies(source, targets)
          targets = validated_target_layers(targets)
          combined = [*forbidden_dependencies.fetch(source, []), *targets].uniq
          copy(forbidden_dependencies: forbidden_dependencies.merge(source => combined))
        end

        def perform_check(options)
          graph = ArchUnit::Extraction.extract_graph(project_locator, options:)
          nodes = Common::Projection.project_to_nodes(graph)
          edges = Common::Projection.project_edges(graph, Common::Projection.per_internal_edge)

          empty_policy_violations(nodes, options) +
            Assertion.gather_layer_dependency_violations(
              edges, layer_definitions, allowed_dependencies, forbidden_dependencies
            )
        end

        def empty_policy_violations(nodes, options)
          return [] if options.allow_empty_tests?

          policy_source_names.filter_map do |name|
            definition = layer_definition(name)
            next if nodes.any? { |node| definition.matches?(node.label) }

            Common::Assertion::EmptyTestViolation.new(filters: definition.filters)
          end
        end

        def policy_source_names
          [*allowed_dependencies.keys, *forbidden_dependencies.keys].uniq
        end

        def copy(overrides = {})
          self.class.new(
            project_locator: overrides.fetch(:project_locator, project_locator),
            layer_definitions: overrides.fetch(:layer_definitions, layer_definitions),
            allowed_dependencies: overrides.fetch(:allowed_dependencies, allowed_dependencies),
            forbidden_dependencies: overrides.fetch(:forbidden_dependencies, forbidden_dependencies)
          )
        end

        def replace_definition(old_definition, new_definition)
          layer_definitions.map do |definition|
            definition.equal?(old_definition) ? new_definition : definition
          end
        end

        def layer_definition(name)
          layer_definitions.find { |definition| definition.name == name }
        end

        def ensure_defined_layer!(name)
          return if layer_definition(name)

          raise ArgumentError, "layer '#{name}' must be defined before it can have a policy"
        end

        def validated_target_layers(values)
          names = Array(values).map { |value| validated_layer_name(value) }.uniq
          undefined = names.reject { |name| layer_definition(name) }
          unless undefined.empty?
            raise ArgumentError, "undefined target layer: #{undefined.join(', ')}"
          end

          names
        end
      end
    end
  end
end
