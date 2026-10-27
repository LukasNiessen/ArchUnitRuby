# frozen_string_literal: true

require 'archunit/cli'

RSpec.describe ArchUnit::CLI::Options do
  let(:root) { File.expand_path('../..', __dir__) }

  it 'defaults to check, import analysis and a configuration in the selected root' do
    options = described_class.new([], cwd: root).parse!

    expect(options.command).to eq('check')
    expect(options.project_root).to eq(root)
    expect(options.config_path).to eq(File.join(root, '.archunit.rb'))
    expect(options.dependency_analysis).to eq('imports')
    expect(options.format).to eq('text')
  end

  it 'resolves explicit project and configuration paths against the invocation directory' do
    arguments = %w[explain --project .. --config ../custom.rb --format json
                   --dependency-analysis imports_and_constants]
    original = arguments.dup
    options = described_class.new(arguments, cwd: root).parse!

    expect(options.command).to eq('explain')
    expect(options.project_root).to eq(File.expand_path('..', root))
    expect(options.config_path).to eq(File.expand_path('../custom.rb', root))
    expect(options.format).to eq('json')
    expect(options.dependency_analysis).to eq('imports_and_constants')
    expect(arguments).to eq(original)
  end

  %w[--help -h --version -v].each do |flag|
    it "handles #{flag} without requiring a valid project" do
      options = described_class.new([flag], cwd: File.join(root, 'missing')).parse!

      expect(options.command).to eq(flag.include?('h') ? 'help' : 'version')
    end
  end

  [%w[unknown], %w[check leftover], %w[check --unknown], %w[check --format xml],
   %w[check --dependency-analysis reflection], %w[check --config]].each do |arguments|
    it "rejects invalid arguments #{arguments.join(' ')}" do
      expect { described_class.new(arguments, cwd: root).parse! }.to raise_error(OptionParser::ParseError)
    end
  end

  it 'rejects a missing project root' do
    expect do
      described_class.new(%w[check --project absent], cwd: root).parse!
    end.to raise_error(ArgumentError, /Project directory does not exist/)
  end

  it 'recognizes JSON even when an earlier unknown flag interrupts option parsing' do
    options = described_class.new(%w[check --unknown --format=json], cwd: root)

    expect(options.format).to eq('json')
    expect { options.parse! }.to raise_error(OptionParser::InvalidOption)
  end
end
