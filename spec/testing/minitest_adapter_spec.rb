# frozen_string_literal: true

require 'minitest'

RSpec.describe ArchUnit::Testing::MinitestAdapter do
  before { described_class.install! }

  let(:assertion_context) do
    Class.new do
      include Minitest::Assertions

      attr_accessor :assertions
    end.new
  end

  before { assertion_context.assertions = 0 }

  let(:rule_class) do
    Class.new do
      include ArchUnit::Checkable

      def initialize(violations)
        @violations = violations
      end

      private

      attr_reader :violations

      def perform_check(_options)
        violations
      end
    end
  end

  it 'installs assert_passes into the native assertion module' do
    expect(described_class).to be_installed
    expect(assertion_context).to respond_to(:assert_passes)
    expect(assertion_context.assert_passes(rule_class.new([]))).to be(true)
    expect(assertion_context.assertions).to eq(1)
  end

  it 'raises Minitest::Assertion with the shared formatted message' do
    violation = ArchUnit::EmptyTestViolation.new(filters: [])

    expect { assertion_context.assert_passes(rule_class.new([violation])) }.to raise_error(
      Minitest::Assertion,
      /Found 1 architecture violation.*No files matched/m
    )
  end

  it 'silently reports that Minitest is unavailable without installing' do
    hide_const('Minitest')

    expect(described_class.install!).to be_nil
    expect(described_class).not_to be_installed
  end
end
