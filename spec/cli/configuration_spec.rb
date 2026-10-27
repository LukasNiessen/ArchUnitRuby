# frozen_string_literal: true

require 'archunit/cli'
require 'tmpdir'
require 'fileutils'

RSpec.describe ArchUnit::CLI::Configuration do
  around do |example|
    Dir.mktmpdir('archunit-cli-configuration') do |directory|
      @root = directory
      example.run
    end
  end

  it 'provides every rule entry point rooted at the selected project' do
    configuration = described_class.new(@root)
    scopes = [configuration.project_files, configuration.files, configuration.project_layers,
              configuration.layers, configuration.project_slices, configuration.metrics]

    expect(scopes.map(&:project_locator)).to all(eq(@root))
  end

  it 'normalizes rule names and retains lazy checkables and rationale' do
    configuration = described_class.new(@root)
    configuration.rule('  boundary  ') { project_files.should.have_no_cycles.because('No cycles') }

    expect(configuration.rules.first.name).to eq('boundary')
    expect(configuration.rules.first.checkable.rationale).to eq('No cycles')
  end

  [nil, '', '  ', 7].each do |name|
    it "rejects invalid rule name #{name.inspect}" do
      expect do
        described_class.new(@root).rule(name) { project_files.should.have_no_cycles }
      end.to raise_error(ArgumentError, /non-empty name/)
    end
  end

  it 'requires a block and a completed rule, not a selector or arbitrary object' do
    configuration = described_class.new(@root)

    expect { configuration.rule('missing') }.to raise_error(ArgumentError, /block/)
    expect do
      configuration.rule('selector') do
        project_files
      end
    end.to raise_error(ArgumentError, /completed/)
  end

  it 'rejects duplicate normalized names' do
    configuration = described_class.new(@root)
    configuration.rule('boundary') { project_files.should.have_no_cycles }

    expect do
      configuration.rule(' boundary ') { project_files.should.have_no_cycles }
    end.to raise_error(ArgumentError, /Duplicate rule name/)
  end

  it 'loads the explicitly trusted configuration without changing the working directory' do
    path = File.join(@root, '.archunit.rb')
    File.write(path, "rule('library') { project_files.should.have_no_cycles }")
    cwd = Dir.pwd
    rules = described_class.new(@root).load(path)

    expect(rules.map(&:name)).to eq(['library'])
    expect(rules).to be_frozen
    expect(Dir.pwd).to eq(cwd)
  end

  it 'rejects a configuration without any rules' do
    path = File.join(@root, '.archunit.rb')
    File.write(path, '# nothing declared')

    expect do
      described_class.new(@root).load(path)
    end.to raise_error(ArgumentError, /at least one rule/)
  end
end
