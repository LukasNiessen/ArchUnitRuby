# frozen_string_literal: true

require 'date'

# Maintainer-side validation, not part of the installed gem or application analysis.
module ArchUnitReleaseMetadata
  module_function

  def errors(root:, version:, release: false)
    common_errors(root, version) + (release ? release_errors(root, version) : [])
  rescue SystemCallError => e
    ["Release metadata is unavailable: #{e.message}"]
  end

  def common_errors(root, version)
    failures = []
    failures << "CHANGELOG.md has no heading for #{version}." unless changelog_entry(root, version)
    lock = File.read(File.join(root, 'Gemfile.lock'))
    unless lock.match?(/^    archunit \(#{Regexp.escape(version)}\)$/)
      failures << "Gemfile.lock does not lock the local archunit gem at #{version}."
    end
    failures
  end

  def release_errors(root, version)
    failures = []
    unless dated_entry?(changelog_entry(root, version), version)
      failures << 'A release needs a dated CHANGELOG heading, not an unreleased or invalid date.'
    end
    readme = File.read(File.join(root, 'README.md'))
    unless readme.match?(/gem ['"]archunit['"],\s*['"]~> #{Regexp.escape(version)}['"]/)
      failures << "Update the README installation example to ~> #{version} before release."
    end
    failures
  end

  def changelog_entry(root, version)
    File.foreach(File.join(root, 'CHANGELOG.md')).find do |line|
      line.match?(/^## #{Regexp.escape(version)}(?:\s|$)/)
    end&.strip
  end

  def dated_entry?(entry, version)
    date = entry&.match(/\A## #{Regexp.escape(version)} - (\d{4}-\d{2}-\d{2})\z/)&.[](1)
    return false unless date

    Date.iso8601(date)
    true
  rescue Date::Error
    false
  end
end

if $PROGRAM_NAME == __FILE__
  require_relative '../lib/archunit/version'

  release = !ARGV.delete('--release').nil?
  abort 'Usage: ruby scripts/check_release_metadata.rb [--release]' unless ARGV.empty?
  errors = ArchUnitReleaseMetadata.errors(
    root: File.expand_path('..', __dir__), version: ArchUnit::VERSION, release:
  )
  abort "Release metadata check failed:\n- #{errors.join("\n- ")}" unless errors.empty?
  mode = release ? 'release' : 'development'
  puts "Release metadata is synchronized for #{ArchUnit::VERSION} (#{mode})."
end
