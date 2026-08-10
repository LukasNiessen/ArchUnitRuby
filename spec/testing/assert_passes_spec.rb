# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Testing, '.assert_passes' do
  around do |example|
    Dir.mktmpdir('archunit-assert-passes') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  before do
    create_file('lib/api.rb', "require_relative 'database'\n")
    create_file('lib/database.rb')
  end

  it 'returns nil when a rule has no violations' do
    rule = ArchUnit.files(@project_root).should.have_no_cycles

    expect(described_class.assert_passes(rule)).to be_nil
    expect(ArchUnit.assert_passes(rule)).to be_nil
  end

  it 'raises a framework-neutral assertion failure with the shared formatted result' do
    rule = ArchUnit.files(@project_root)
                   .in_file('lib/api.rb')
                   .should_not.depend_on_files
                   .in_path('lib/database.rb')

    expect { ArchUnit.assert_passes(rule) }.to raise_error(
      ArchUnit::AssertionFailure
    ) do |error|
      expect(error).to be_a(StandardError)
      expect(error.result).to be_failed
      expect(error.message).to include(
        'Found 1 architecture violation:',
        'File dependency violation',
        "File 'lib/api.rb' depends on forbidden file 'lib/database.rb'."
      )
    end
  end

  it 'passes CheckOptions through to the rule unchanged' do
    rule = ArchUnit.files(@project_root)
                   .in_folder('missing/**')
                   .should.have_no_cycles
    options = ArchUnit::CheckOptions.new(allow_empty_tests: true)

    expect(ArchUnit.assert_passes(rule, options)).to be_nil
  end

  it 'uses ResultFactory as the only message construction path' do
    violation = ArchUnit::EmptyTestViolation.new(filters: [])
    rule_class = Class.new do
      include ArchUnit::Checkable

      define_method(:perform_check) { |_options| [violation] }
      private :perform_check
    end
    rule = rule_class.new

    expect(ArchUnit::ResultFactory).to receive(:from_violations)
      .with([violation]).and_call_original
    expect { ArchUnit.assert_passes(rule) }.to raise_error(ArchUnit::AssertionFailure)
  end

  it 'rejects non-rules and invalid assertion failure results' do
    expect { ArchUnit.assert_passes(Object.new) }
      .to raise_error(ArgumentError, /Checkable/)
    passing = ArchUnit::TestResult.new(passed: true, message: 'passed')
    expect { ArchUnit::AssertionFailure.new(passing) }
      .to raise_error(ArgumentError, /failed TestResult/)
    expect { ArchUnit::AssertionFailure.new(Object.new) }
      .to raise_error(ArgumentError, /failed TestResult/)
  end

  it 'is available from the gem public surface' do
    expect(ArchUnit::AssertionFailure).to equal(described_class::AssertionFailure)
    expect(ArchUnit).to respond_to(:assert_passes)
  end
end
