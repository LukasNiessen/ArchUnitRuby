# frozen_string_literal: true

module ArchUnit
  module Testing
    # RSpec's matcher protocol, delegating all evaluation and prose to shared testing code.
    class RSpecPassMatcher
      def initialize(options = nil)
        @options = options
      end

      def matches?(rule)
        matches_expectation?(rule, expected_to_pass: true)
      end

      # RSpec's matcher protocol fixes this method name.
      # rubocop:disable Naming/PredicatePrefix
      def does_not_match?(rule)
        matches_expectation?(rule, expected_to_pass: false)
      end
      # rubocop:enable Naming/PredicatePrefix

      def failure_message
        result.message
      end
      alias failure_message_when_negated failure_message

      private

      attr_reader :options, :result

      def matches_expectation?(rule, expected_to_pass:)
        @result = ArchUnit::Testing.result_for(rule, options, expected_to_pass:)
        result.passed?
      end
    end

    # Methods mixed into RSpec's matcher namespace when the framework is present.
    module RSpecMatchers
      def pass(options = nil)
        RSpecPassMatcher.new(options)
      end
    end

    # Installs the native `expect(rule).to pass` matcher when RSpec is already loaded.
    module RSpecAdapter
      module_function

      def install!
        return unless rspec_available?
        return if installed?

        ::RSpec::Matchers.include(RSpecMatchers)
        @installed = true
        nil
      end

      def installed?
        @installed == true
      end

      def rspec_available?
        return false unless defined?(::RSpec)

        require 'rspec/matchers' unless defined?(::RSpec::Matchers)
        defined?(::RSpec::Matchers)
      rescue LoadError
        false
      end
      private_class_method :rspec_available?
    end
  end
end

ArchUnit::Testing::RSpecAdapter.install!
