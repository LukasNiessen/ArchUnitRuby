# frozen_string_literal: true

require 'fileutils'
require 'time'
require_relative 'logging_options'

module ArchUnit
  module Common
    module Logging
      # A logger owned by one check invocation; no configuration or output state is global.
      class CheckLogger
        LEVEL_PRIORITIES = { debug: 0, info: 1, warn: 2, error: 3 }.freeze

        attr_reader :log_path

        def initialize(options = nil, clock: -> { Time.now.utc })
          validate_options(options)
          raise ArgumentError, 'clock must respond to call' unless clock.respond_to?(:call)

          @options = options
          @clock = clock
          @file = nil
          @log_path = nil
          @mutex = Mutex.new
        end

        def start_check(check_name)
          write(:info, "start check: #{label(check_name, 'check_name')}")
        end

        def end_check(check_name, violation_count: nil, error: nil)
          name = label(check_name, 'check_name')
          if error
            write(:error, "end check: #{name} failed with #{error.class}: #{error.message}")
          else
            write(:info, "end check: #{name} (#{Integer(violation_count)} violations)")
          end
        end

        def log_progress(message)
          write(:info, "log progress: #{label(message, 'message')}")
        end

        def log_violation(violation)
          raise ArgumentError, 'violation is required' if violation.nil?

          write(:warn, "log violation: #{violation_description(violation)}")
        end

        def log_metric(name:, value:, subject: nil)
          metric = label(name, 'name')
          context = subject.nil? ? '' : " [#{subject}]"
          write(:debug, "log metric: #{metric}=#{value}#{context}")
        end

        def close
          @mutex.synchronize do
            @file&.close
            @file = nil
          end
          nil
        end

        private

        def validate_options(value)
          return if value.nil? || value.is_a?(LoggingOptions)

          raise ArgumentError, 'options must be a LoggingOptions value or nil'
        end

        def write(level, message)
          return if @options.nil? || !enabled?(level)

          timestamp = current_time
          line = "[#{timestamp.iso8601(6)}] [#{level.to_s.upcase}] #{message}\n"
          @mutex.synchronize do
            @options.io&.write(line)
            output_file(timestamp)&.write(line)
          end
          nil
        end

        def enabled?(level)
          LEVEL_PRIORITIES.fetch(level) >= LEVEL_PRIORITIES.fetch(@options.level)
        end

        def current_time
          value = @clock.call
          raise ArgumentError, 'clock must return a Time' unless value.is_a?(Time)

          value.utc
        end

        def output_file(timestamp)
          return unless @options.file_output?
          return @file if @file

          FileUtils.mkdir_p(@options.output_directory)
          @log_path = File.join(
            @options.output_directory,
            "archunit-#{timestamp.strftime('%Y-%m-%d_%H-%M-%S-%6N')}.log"
          ).freeze
          @file = File.open(@log_path, @options.append ? 'ab' : 'wb')
        end

        def label(value, attribute)
          text = value.to_s
          return text unless text.empty?

          raise ArgumentError, "#{attribute} must not be empty"
        end

        def violation_description(violation)
          description = violation.class.name.to_s
          description = violation.class.to_s if description.empty?
          return description unless violation.respond_to?(:identifier)

          "#{description} [#{violation.identifier}]"
        end
      end
    end
  end
end
