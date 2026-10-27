# frozen_string_literal: true

require 'json'
require_relative '../version'
require_relative '../testing/violation_factory'
require_relative '../error/source_parse_error'

module ArchUnit
  module CLI
    # Internal presentation adapter reusing the shared violation vocabulary.
    # @api private
    class Report
      attr_reader :payload

      def initialize(options)
        @payload = {
          schema_version: 1, archunit_version: ArchUnit::VERSION, command: options.command,
          project_root: options.project_root, config_path: options.config_path,
          dependency_analysis: options.dependency_analysis, status: 'error', rules: []
        }
      end

      def add_rule(rule, violations: nil)
        payload[:rules] << {
          name: rule.name, rationale: rule.checkable.rationale, status: rule_status(violations),
          violations: (violations || []).map { |violation| violation_payload(violation) }
        }
      end

      def finish(status)
        payload[:status] = status
        payload[:summary] = {
          rule_count: payload[:rules].length,
          violation_count: payload[:rules].sum { |rule| rule[:violations].length }
        }
        self
      end

      def fail_with(error, rule_name: nil)
        payload[:error] = { type: error.class.name, message: error.message, rule_name: }
        if error.is_a?(SourceParseError)
          payload[:error][:diagnostics] = error.diagnostics.map(&:to_h)
        end
        finish('error')
      end

      def write(out:, err:, format:)
        return out.puts(JSON.pretty_generate(payload)) if format == 'json'
        return err.puts("ArchUnit error: #{payload[:error][:message]}") if payload[:error]

        write_text(out)
      end

      private

      def rule_status(violations)
        return 'not_checked' unless violations

        violations.empty? ? 'passed' : 'failed'
      end

      def violation_payload(violation)
        formatted = Testing::ViolationFactory.from_violation(violation)
        { type: violation.class.name, message: formatted.message, details: formatted.details }
      end

      def write_text(out)
        out.puts("ArchUnit #{ArchUnit::VERSION} — #{payload[:status]} " \
                 "(#{payload[:dependency_analysis]})")
        out.puts("Project: #{payload[:project_root]}\nConfiguration: #{payload[:config_path]}")
        write_notice(out)
        payload[:rules].each { |rule| write_rule(rule, out) }
      end

      def write_notice(out)
        case payload[:status]
        when 'configured'
          out.puts('Rules are configured, not evaluated.')
        when 'initialized'
          out.puts('Review and customize the trusted Ruby configuration before checking.')
        end
      end

      def write_rule(rule, out)
        out.puts("[#{rule[:status]}] #{rule[:name]}")
        out.puts("  Because: #{rule[:rationale]}") if rule[:rationale]
        rule[:violations].each do |violation|
          out.puts("  #{violation[:message]}\n    #{violation[:details]}")
        end
      end
    end
  end
end
