# frozen_string_literal: true

RSpec.describe ArchUnit::Testing::RSpecAdapter do
  let(:passing_rule) do
    Class.new do
      include ArchUnit::Checkable

      private

      def perform_check(_options)
        []
      end
    end.new
  end

  let(:failing_rule) do
    violation = ArchUnit::EmptyTestViolation.new(filters: [])
    Class.new do
      include ArchUnit::Checkable

      define_method(:perform_check) { |_options| [violation] }
      private :perform_check
    end.new
  end

  it 'registers the native matcher automatically when RSpec is loaded' do
    expect(described_class).to be_installed
    expect(passing_rule).to pass
    expect(failing_rule).not_to pass
  end

  it 'reports positive failures through the shared result factory' do
    expect { expect(failing_rule).to pass }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      /Found 1 architecture violation.*No files matched/m
    )
  end

  it 'supports RSpec negation with a centrally shaped failure message' do
    expect { expect(passing_rule).not_to pass }.to raise_error(
      RSpec::Expectations::ExpectationNotMetError,
      /Expected architecture violations, but none were found/
    )
  end

  it 'passes CheckOptions through the matcher' do
    options = ArchUnit::CheckOptions.new(allow_empty_tests: true)
    expect(passing_rule).to pass(options)
  end
end
