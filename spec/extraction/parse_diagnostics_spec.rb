# frozen_string_literal: true

require 'fileutils'
require 'minitest'
require 'stringio'
require 'tmpdir'

RSpec.describe 'strict source parsing' do
  around do |example|
    Dir.mktmpdir('archunit-parse-diagnostics') do |directory|
      @root = File.realpath(directory)
      File.write(File.join(@root, 'Gemfile'), "raise 'must never execute'\n")
      source('app/db/store.rb', 'module Db; class Store; end; end')
      source('app/api/request.rb', "require_relative '../db/store'\nclass Broken <\n")
      ArchUnit.clear_graph_cache
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  def source(path, contents)
    absolute = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(absolute))
    File.write(absolute, contents)
  end

  def rule
    ArchUnit.project_files(@root).in_path('app/api/**')
            .should_not.depend_on_files.in_path('app/db/**')
  end

  %i[imports imports_and_constants].each do |mode|
    it "rejects the exact malformed-source reproducer in #{mode} mode" do
      options = ArchUnit::CheckOptions.new(dependency_analysis: mode)
      expect { rule.check(options) }.to raise_error(ArchUnit::TechnicalError, /request.rb/)
    end

    it "reports structured diagnostics and a malformed-file counter in #{mode} mode" do
      options = ArchUnit::CheckOptions.new(dependency_analysis: mode)
      profile = ArchUnit::Extraction::ExtractionProfile.new
      expect do
        ArchUnit::Extraction.extract_graph(@root, options:, profile:)
      end.to raise_error(ArchUnit::SourceParseError) { |error|
        expect(error.diagnostics).not_to be_empty
        expect(error.diagnostics).to be_frozen
        attributes = { path: File.join(@root, 'app/api/request.rb').tr('\\', '/'),
                       line: be >= 2, column: be >= 1, message: be_a(String) }
        expect(error.diagnostics).to all(have_attributes(attributes))
        expect(error.diagnostics).to all(be_frozen)
        expect(error.diagnostics.first.to_h.keys).to eq(%i[path line column message])
      }
      expect(profile.counters.fetch(:malformed_files)).to eq(1)
      expect(profile).not_to be_cache_hit
    end
  end

  it 'propagates technical failure through assertions and both framework adapters' do
    expect { ArchUnit.assert_passes(rule) }.to raise_error(ArchUnit::TechnicalError)
    expect { expect(rule).to pass }.to raise_error(ArchUnit::TechnicalError)
    context = Class.new do
      include Minitest::Assertions

      attr_accessor :assertions
    end.new
    context.assertions = 0
    expect { context.assert_passes(rule) }.to raise_error(ArchUnit::TechnicalError)
    expect(context.assertions).to eq(0)
  end

  it 'does not cache failed builds and rejects new errors after explicit cache clearing' do
    expect { rule.check }.to raise_error(ArchUnit::TechnicalError)
    source('app/api/request.rb', "require_relative '../db/store'\n")
    expect(rule.check.length).to eq(1)
    source('app/db/store.rb', 'class Broken <')
    expect(rule.check.length).to eq(1) # Source edits retain the documented explicit-clear policy.
    expect do
      rule.check(ArchUnit::CheckOptions.new(clear_cache: true))
    end.to raise_error(ArchUnit::SourceParseError, /store.rb/)
    expect { rule.check }.to raise_error(ArchUnit::SourceParseError)
  end

  it 'does not inspect malformed files excluded by the project source policy' do
    source('.archignore', "app/api/\n")
    graph = ArchUnit::Extraction.extract_graph(@root)
    expect(graph.map(&:source).uniq).to eq(['app/db/store.rb'])
    expect(ArchUnit.metrics(@root).count.classes.measure.length).to eq(1)
  end

  it 'prevents partial graph reports and misleading zero-valued AST metrics' do
    expect { ArchUnit.project_graph(@root).to_json }.to raise_error(ArchUnit::TechnicalError)
    expect { ArchUnit.metrics(@root).count.classes.measure }.to raise_error(ArchUnit::TechnicalError)
  end

  it 'logs the parser failure rather than a successful check' do
    output = StringIO.new
    options = ArchUnit::CheckOptions.new(logging: ArchUnit::LoggingOptions.new(io: output))
    expect { rule.check(options) }.to raise_error(ArchUnit::TechnicalError)
    expect(output.string).to include('request.rb', 'SourceParseError')
  end
end
