# frozen_string_literal: true

require_relative '../common/extraction/edge'
require_relative 'constant_visitor'

module ArchUnit
  module Extraction
    # Bounded project definition index. Unknown/ambiguous names never invent file targets.
    class ConstantIndex
      Location = Data.define(:source, :line_number)
      MAX_NAMESPACE_PASSES = 8

      def initialize(analyses, profile: nil)
        @analyses = analyses
        @profile = profile
        @visitors = stabilized_visitors
        @definitions = definition_locations
        @namespaces = namespace_names(@visitors)
        @inherited_namespaces = @visitors.values.flat_map(&:inherited_namespaces).to_set
      end

      def edges
        @visitors.flat_map do |source, visitor|
          visitor.references.filter_map { |reference| resolve_edge(source, reference) }
        end
      end

      private

      def stabilized_visitors
        visitors = collect
        MAX_NAMESPACE_PASSES.times do
          names = namespace_names(visitors)
          visitors = collect(namespace_names: names)
          return visitors if namespace_names(visitors) == names
        end
        unresolved_count = visitors.values.sum { |visitor| visitor.references.length }
        @profile&.increment(:unresolved_constant_references, unresolved_count)
        {}
      end

      def collect(namespace_names: nil)
        @analyses.to_h do |source, result|
          visitor = ConstantVisitor.new(namespace_names:)
          visitor.visit(result.value)
          [source, visitor]
        end
      end

      def namespace_names(visitors)
        visitors.values.flat_map(&:definitions).each_with_object(Set.new) do |definition, names|
          parts = definition.name.split('::')
          parts.length.times { |index| names << parts.take(index + 1).join('::') }
        end
      end

      def definition_locations
        map = Hash.new { |hash, key| hash[key] = [] }
        @visitors.each do |source, visitor|
          visitor.definitions.each do |definition|
            map[definition.name] << Location.new(source:, line_number: definition.line_number)
          end
        end
        map
      end

      def resolve_edge(source, reference)
        name = resolve_name(reference)
        locations = name ? @definitions.fetch(name, []) : []
        return unresolved(:unresolved_constant_references) if locations.empty?
        return unresolved(:ambiguous_constant_references) if locations.map(&:source).uniq.length > 1

        location = locations.first
        return if source == location.source

        evidence_edge(source, reference, location)
      end

      def resolve_name(reference)
        name = reference.name
        return name.delete_prefix('::') if name.start_with?('::')

        head = name.split('::').first
        owner = reference.nesting.find { |scope| @namespaces.include?("#{scope}::#{head}") }
        return "#{owner}::#{name}" if owner
        return if @inherited_namespaces.include?(reference.inherited_scope)

        name
      end

      def unresolved(counter)
        @profile&.increment(counter)
        nil
      end

      def evidence_edge(source, reference, location)
        kind = Common::Extraction::ImportKind::CONSTANT_REFERENCE
        evidence = Common::Extraction::DependencyEvidence.new(
          source:, kind:, name: reference.name, line_number: reference.line_number,
          end_line: reference.end_line, target_line_number: location.line_number
        )
        Common::Extraction::Edge.new(
          source:, target: location.source, external: false,
          import_kinds: [kind], evidence: [evidence]
        )
      end
    end
    private_constant :ConstantIndex
  end
end
