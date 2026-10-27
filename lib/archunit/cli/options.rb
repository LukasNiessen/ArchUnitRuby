# frozen_string_literal: true

require 'optparse'

module ArchUnit
  module CLI
    # Internal command parsing; does not discover or execute project code.
    # @api private
    class Options
      attr_reader :command, :project_root, :config_path, :format, :dependency_analysis, :parser

      def initialize(arguments, cwd:)
        @arguments = arguments.dup
        @cwd = cwd
        @command = @arguments.first&.start_with?('-') ? 'check' : (@arguments.shift || 'check')
        @project_root = File.expand_path(cwd)
        @format = json_requested? ? 'json' : 'text'
        @dependency_analysis = 'imports'
        @parser = build_parser
      end

      def parse!
        parser.parse!(@arguments)
        validate_arguments
        return self if %w[help version].include?(command)

        unless File.directory?(project_root)
          raise ArgumentError, "Project directory does not exist: #{project_root}"
        end

        @config_path ||= File.join(project_root, '.archunit.rb')
        self
      end

      private

      def validate_arguments
        unless @arguments.empty?
          raise OptionParser::InvalidArgument, "unexpected arguments: #{@arguments.join(' ')}"
        end
        return if %w[init check explain help version].include?(command)

        raise OptionParser::InvalidArgument, "unknown command: #{command}"
      end

      def json_requested?
        @arguments.include?('--format=json') ||
          @arguments.each_cons(2).any? { |flag, value| flag == '--format' && value == 'json' }
      end

      def build_parser
        OptionParser.new do |options|
          options.banner = 'Usage: archunit [init|check|explain] [options]'
          project_options(options)
          output_options(options)
        end
      end

      def project_options(options)
        options.on('--project DIRECTORY', 'Project root (default: working directory)') do |value|
          @project_root = File.expand_path(value, @cwd)
        end
        options.on('--config FILE',
                   'Trusted Ruby config (default: PROJECT/.archunit.rb)') do |value|
          @config_path = File.expand_path(value, @cwd)
        end
      end

      def output_options(options)
        options.on('--format FORMAT', %w[text json], 'Output format: text or json') do |value|
          @format = value
        end
        options.on('--dependency-analysis MODE', %w[imports imports_and_constants],
                   'Static analysis mode (default: imports)') do |value|
          @dependency_analysis = value
        end
        options.on('-h', '--help', 'Show help without loading config') { @command = 'help' }
        options.on('-v', '--version', 'Show the installed version') { @command = 'version' }
      end
    end
  end
end
