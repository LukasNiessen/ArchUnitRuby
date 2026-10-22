# frozen_string_literal: true

require 'bundler/audit/scanner'
require 'fileutils'
require 'json'
require 'optparse'
require 'tmpdir'

# Development tooling only: no scanner dependency is added to the published gem.
module DependencySecurity
  # Fail-closed adapter around the audited lockfile scanner and its advisory database.
  class Checker
    def initialize(root:, database_path:)
      @root = File.expand_path(root)
      # Database advisory globs interpret Windows backslashes as escapes.
      @database_path = File.expand_path(database_path).tr('\\', '/')
    end

    def run(update: true)
      database = load_database(update)
      # rubocop:disable-next Style/ZeroLengthPredicate -- Database does not implement empty?.
      raise 'The advisory database is empty; refusing a false-clean result' if database.size.zero?

      verify_detection(database)
      report = Bundler::Audit::Scanner.new(@root, 'Gemfile.lock', database).report
      report.to_h.merge(
        database_commit: database.commit_id, advisory_count: database.size,
        vulnerable_fixture_detected: true
      )
    end

    private

    def load_database(update)
      unless Bundler::Audit::Database.exists?(@database_path)
        raise 'No advisory database is available for an offline scan' unless update

        return Bundler::Audit::Database.download(path: @database_path, quiet: true)
      end
      database = Bundler::Audit::Database.new(@database_path)
      raise 'Advisory database update did not complete' if update && !database.update!(quiet: true)

      database
    end

    def verify_detection(database)
      Dir.mktmpdir('archunit-audit-health') do |root|
        File.write(File.join(root, 'Gemfile.lock'), vulnerable_lockfile)
        report = Bundler::Audit::Scanner.new(root, 'Gemfile.lock', database).report
        unless report.unpatched_gems.any? { |result| result.gem.name == 'rack' }
          raise 'The scanner missed a known-vulnerable Rack fixture; refusing a false-clean result'
        end
      end
    end

    def vulnerable_lockfile
      "GEM\n  remote: https://rubygems.org/\n  specs:\n    rack (1.0.0)\n\n" \
        "PLATFORMS\n  ruby\n\nDEPENDENCIES\n  rack (= 1.0.0)\n"
    end
  end

  module_function

  def execute(arguments)
    root = File.expand_path('..', __dir__)
    options = parse_options(arguments, root)
    result = Checker.new(root:, database_path: options[:database]).run(update: options[:update])
    complete_scan(options, result)
  rescue StandardError => e
    failed_scan(options, e)
  end

  def complete_scan(options, result)
    write_report(options[:output], result)
    puts "Checked #{result[:advisory_count]} advisories; #{result[:results].length} findings."
    result[:results].empty? ? 0 : 1
  end

  def failed_scan(options, error)
    write_report(options[:output], error: "#{error.class}: #{error.message}") if options
    warn error.message
    1
  end

  def parse_options(arguments, root)
    options = { database: ENV.fetch('BUNDLER_AUDIT_DB', File.join(root, 'pkg/ruby-advisory-db')),
                output: File.join(root, 'pkg/dependency-audit.json'), update: true }
    OptionParser.new do |parser|
      parser.on('--database PATH') { |value| options[:database] = value }
      parser.on('--output PATH') { |value| options[:output] = value }
      parser.on('--no-update') { options[:update] = false }
    end.parse!(arguments)
    raise ArgumentError, 'Unexpected positional arguments' unless arguments.empty?

    options
  end

  def write_report(path, payload)
    FileUtils.mkdir_p(File.dirname(File.expand_path(path)))
    File.write(path, JSON.pretty_generate(payload))
  end
end

exit DependencySecurity.execute(ARGV) if $PROGRAM_NAME == __FILE__
