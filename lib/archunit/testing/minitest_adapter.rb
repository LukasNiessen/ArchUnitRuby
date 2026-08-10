# frozen_string_literal: true

module ArchUnit
  module Testing
    # Native Minitest assertion methods mixed in only when Minitest is already loaded.
    module MinitestAssertions
      def assert_passes(rule, options = nil)
        result = ArchUnit::Testing.result_for(rule, options)
        assert(result.passed?, result.message)
      end
    end

    # Silently installs the helper without making Minitest a runtime dependency.
    module MinitestAdapter
      module_function

      def install!
        return unless defined?(::Minitest::Assertions)
        return if installed?

        ::Minitest::Assertions.include(MinitestAssertions)
        nil
      end

      def installed?
        defined?(::Minitest::Assertions) &&
          ::Minitest::Assertions.include?(MinitestAssertions)
      end
    end
  end
end

ArchUnit::Testing::MinitestAdapter.install!
