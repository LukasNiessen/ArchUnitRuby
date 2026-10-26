# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'

RSpec.describe 'the enforced coverage scope' do
  it 'includes every runtime file, excludes loaded tooling, and preserves coverage thresholds' do
    root = File.expand_path('../..', __dir__)
    # Inspect the real settings in a separate process without merging its partial execution into
    # the parent suite's coverage result. Only the full parent run enforces the percentage gate.
    probe = <<~RUBY
      require 'json'
      require 'rspec/core'
      require_relative 'spec/spec_helper'
      SimpleCov.use_merging false
      SimpleCov.at_exit {}
      require_relative 'benchmark/extraction'
      settings = SimpleCov.minimum_coverage
      files = SimpleCov.result.files.map(&:filename)
      puts JSON.generate(files: files, minimums: settings, loaded: $LOADED_FEATURES)
    RUBY
    stdout, stderr, status = Open3.capture3(
      { 'COVERAGE' => 'true' }, RbConfig.ruby, '-Ilib', '-e', probe, chdir: root
    )
    expect(status.success?).to be(true), stderr
    result = JSON.parse(stdout)
    expected = Dir.glob(File.join(root, 'lib/**/*.rb')).map { |path| File.expand_path(path) }
    normalize = ->(paths) { paths.map { |path| path.tr('\\', '/') }.sort }
    expect(normalize.call(result.fetch('files'))).to eq(normalize.call(expected))
    loaded_tools = %w[spec/spec_helper.rb benchmark/extraction.rb].map do |path|
      File.join(root, path).tr('\\', '/')
    end
    expect(normalize.call(result.fetch('loaded'))).to include(*loaded_tools)
    expect(result.fetch('minimums')).to eq('line' => 98, 'branch' => 90)
  end
end
