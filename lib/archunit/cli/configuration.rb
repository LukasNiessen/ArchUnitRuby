# frozen_string_literal: true

require_relative '../common/fluentapi/checkable'
require_relative '../files/fluentapi/files'
require_relative '../layers/fluentapi/layers'
require_relative '../slices/fluentapi/slices'
require_relative '../metrics/fluentapi/metrics'

module ArchUnit
  module CLI
    # Trusted executable Ruby configuration. This context is deliberately not a sandbox.
    # @api private
    class Configuration
      Rule = Data.define(:name, :checkable)
      STARTER = <<~RUBY
        # frozen_string_literal: true

        # Trusted Ruby configuration: review this file before running archunit.
        # Customize the scope and add named rules for your project's boundaries.
        rule 'Library files have no dependency cycles' do
          project_files.in_path('lib/**/*.rb').should.have_no_cycles
        end
      RUBY

      attr_reader :rules

      def initialize(project_root)
        @project_root = project_root
        @rules = []
      end

      def load(path)
        instance_eval(File.read(path), path, 1)
        raise ArgumentError, 'Configuration must declare at least one rule' if rules.empty?

        rules.freeze
      end

      def rule(name, &block)
        name = validate_name(name, block)
        checkable = instance_eval(&block)
        validate_checkable(checkable, name)
        rules << Rule.new(name: name.freeze, checkable:)
      end

      def project_files
        Files::FluentApi.project_files(@project_root)
      end
      alias files project_files

      def project_layers
        Layers::FluentApi.project_layers(@project_root)
      end
      alias layers project_layers

      def project_slices
        Slices::FluentApi.project_slices(@project_root)
      end

      def metrics
        Metrics::FluentApi.metrics(@project_root)
      end

      private

      def validate_name(name, block)
        unless name.is_a?(String) && !name.strip.empty? && block
          raise ArgumentError, 'rule requires a non-empty name and a block returning a Checkable'
        end

        name = name.strip
        if rules.any? { |item| item.name == name }
          raise ArgumentError, "Duplicate rule name: #{name}"
        end

        name
      end

      def validate_checkable(checkable, name)
        return if checkable.is_a?(Common::FluentApi::Checkable)

        raise ArgumentError, "Rule '#{name}' must return a completed Checkable rule"
      end
    end
  end
end
