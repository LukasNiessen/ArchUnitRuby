# frozen_string_literal: true

require 'open3'
require 'tmpdir'
require_relative '../../scripts/check_release_metadata'

RSpec.describe ArchUnitReleaseMetadata do
  around do |example|
    Dir.mktmpdir('archunit-release-metadata') do |root|
      @root = root
      write_metadata
      example.run
    end
  end

  def write_metadata
    File.write(File.join(@root, 'CHANGELOG.md'), "# Changelog\n\n## 1.0.0 (unreleased)\n")
    File.write(File.join(@root, 'Gemfile.lock'), "PATH\n  specs:\n    archunit (1.0.0)\n")
    File.write(File.join(@root, 'README.md'), "gem 'archunit', '~> 0.0.1'\n")
  end

  def errors(release: false)
    described_class.errors(root: @root, version: '1.0.0', release:)
  end

  it 'allows unreleased development without pretending the published version changed' do
    expect(errors).to eq([])
  end

  it 'blocks publishing an unreleased changelog and stale README example' do
    expect(errors(release: true)).to contain_exactly(
      /dated CHANGELOG heading/, /README installation example/
    )
  end

  it 'requires an exact changelog version, not a similar prefix' do
    File.write(File.join(@root, 'CHANGELOG.md'), "## 1.0.01 (unreleased)\n")
    expect(errors).to contain_exactly(/no heading for 1\.0\.0/)
  end

  it 'rejects a stale local-gem lock entry' do
    File.write(File.join(@root, 'Gemfile.lock'), "    archunit (0.0.2)\n")
    expect(errors).to contain_exactly(/Gemfile.lock/)
  end

  it 'accepts a prepared release with synchronized instructions and a real calendar date' do
    File.write(File.join(@root, 'CHANGELOG.md'), "## 1.0.0 - 2026-10-20\n")
    File.write(File.join(@root, 'README.md'), "gem 'archunit', '~> 1.0.0'\n")
    expect(errors(release: true)).to eq([])
  end

  it 'rejects an impossible calendar date' do
    File.write(File.join(@root, 'CHANGELOG.md'), "## 1.0.0 - 2026-02-30\n")
    File.write(File.join(@root, 'README.md'), "gem 'archunit', '~> 1.0.0'\n")
    expect(errors(release: true)).to contain_exactly(/dated CHANGELOG/)
  end

  it 'reports missing metadata as an actionable validation failure' do
    File.delete(File.join(@root, 'Gemfile.lock'))
    expect(errors).to contain_exactly(/metadata is unavailable/)
  end

  it 'uses a failing exit status for invalid CLI arguments without attempting a release' do
    script = File.expand_path('../../scripts/check_release_metadata.rb', __dir__)
    _stdout, stderr, status = Open3.capture3(RbConfig.ruby, script, '--not-a-real-option')
    expect(status).not_to be_success
    expect(stderr).to include('Usage:')
  end
end
