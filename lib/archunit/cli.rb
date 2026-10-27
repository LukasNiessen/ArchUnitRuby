# frozen_string_literal: true

require_relative 'cli/runner'

module ArchUnit
  # Command-line composition; load separately from the test-library entry point.
  # Implementation classes are private to the executable, not the fluent public API.
  module CLI
    # Runs a command without terminating the embedding process.
    # @return [Integer] 0 for success, 1 for violations, 2 for command/analysis errors
    def self.run(arguments = ARGV, out: $stdout, err: $stderr, cwd: Dir.pwd)
      Runner.new(arguments, out:, err:, cwd:).run
    end
  end
end
