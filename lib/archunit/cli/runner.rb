# frozen_string_literal: true

require_relative 'options'
require_relative 'configuration'
require_relative 'report'

module ArchUnit
  module CLI
    # Internal command execution; technical errors never become successful rule checks.
    # @api private
    class Runner
      def initialize(arguments, out:, err:, cwd:)
        @options = Options.new(arguments, cwd:)
        @out = out
        @err = err
      end

      def run
        @options.parse!
        return information if %w[help version].include?(@options.command)

        @report = Report.new(@options)
        status = execute
        @report.write(out: @out, err: @err, format: @options.format)
        status
      rescue StandardError, SyntaxError, LoadError, NotImplementedError, SystemExit => e
        # An accidental exit in trusted configuration is not proof that rules passed.
        report_error(e)
      end

      private

      def report_error(error)
        @report ||= Report.new(@options)
        @report.fail_with(error, rule_name: @current_rule&.name)
        @report.write(out: @out, err: @err, format: @options.format)
        2
      end

      def information
        @out.puts(@options.command == 'help' ? @options.parser.to_s : ArchUnit::VERSION)
        0
      end

      def execute
        return initialize_configuration if @options.command == 'init'

        rules = Configuration.new(@options.project_root).load(@options.config_path)
        return explain(rules) if @options.command == 'explain'

        check(rules)
      end

      def initialize_configuration
        File.open(@options.config_path, File::WRONLY | File::CREAT | File::EXCL) do |file|
          file.write(Configuration::STARTER)
        end
        @report.finish('initialized')
        0
      end

      def explain(rules)
        rules.each { |rule| @report.add_rule(rule) }
        @report.finish('configured')
        0
      end

      def check(rules)
        Extraction.clear_graph_cache
        options = Common::FluentApi::CheckOptions.new(
          dependency_analysis: @options.dependency_analysis.to_sym
        )
        check_rules(rules, options)
        failed = @report.payload[:rules].any? { |rule| rule[:status] == 'failed' }
        @report.finish(failed ? 'failed' : 'passed')
        failed ? 1 : 0
      end

      def check_rules(rules, options)
        rules.each do |rule|
          @current_rule = rule
          @report.add_rule(rule, violations: rule.checkable.check(options))
        end
      end
    end
  end
end
