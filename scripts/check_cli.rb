# frozen_string_literal: true

require 'archunit'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# Shared subprocess acceptance check for the checkout and the isolated installed gem.
module ArchUnitCLISmoke
  module_function

  def run
    executable = Gem.bin_path('archunit', 'archunit')
    Dir.mktmpdir('archunit-cli-smoke') do |root|
      check_setup(executable, root)
      prepare_project(root)
      check_imports(executable, root)
      check_constants(executable, root)
      check_parse_failure(executable, root)
    end
    puts "CLI init/check/explain passed for archunit #{ArchUnit::VERSION} from #{executable}"
  end

  def check_setup(executable, root)
    check(executable, root, '--version', expected: 0, json: false)
    check(executable, root, '--help', expected: 0, json: false)
    check(executable, root, 'init', '--format=json', expected: 0)
    check(executable, root, 'init', '--format=json', expected: 2)
    File.write(File.join(root, '.archunit.rb'), 'exit 0')
    check(executable, root, 'check', '--format=json', expected: 2)
  end

  def check_imports(executable, root)
    check(executable, root, 'check', '--format=json', expected: 0)
    File.write(File.join(root, 'app/api/request.rb'), "require_relative '../db/settings'\n")
    failed = check(executable, root, 'check', '--format=json', expected: 1)
    return if failed.dig('summary', 'violation_count') == 1

    abort 'CLI missed the single forbidden edge'
  end

  def check_constants(executable, root)
    File.write(File.join(root, 'app/api/request.rb'), '::Db::DEFAULT')
    check(executable, root, 'check', '--format=json', expected: 0)
    check(executable, root, 'check', '--format=json', '--dependency-analysis',
          'imports_and_constants', expected: 1)
  end

  def check_parse_failure(executable, root)
    File.write(File.join(root, 'app/api/request.rb'), 'class Broken <')
    failure = check(executable, root, 'check', '--format=json', expected: 2)
    abort 'CLI lost parse diagnostics' if failure.dig('error', 'diagnostics').to_a.empty?
    explanation = check(executable, root, 'explain', '--format=json', expected: 0)
    abort 'CLI explanation pretends to check' unless explanation['status'] == 'configured'
  end

  def prepare_project(root)
    %w[api db].each { |folder| FileUtils.mkdir_p(File.join(root, 'app', folder)) }
    File.write(File.join(root, 'Gemfile'), "raise 'Target Gemfile must not execute'")
    File.write(File.join(root, 'app/api/request.rb'), "raise 'Target source must not execute'")
    File.write(File.join(root, 'app/db/settings.rb'), 'module Db; DEFAULT ||= 42; end')
    File.write(File.join(root, '.archunit.rb'), <<~RUBY)
      rule 'API stays out of storage' do
        project_files.in_path('app/api/**').should_not.depend_on_files.in_path('app/db/**')
          .because('Keep storage private')
      end
    RUBY
  end

  def check(executable, root, *arguments, expected:, json: true)
    output, errors, status = Open3.capture3(RbConfig.ruby, executable, *arguments, chdir: root)
    unless status.exitstatus == expected && errors.empty?
      abort "CLI #{arguments.inspect}: expected #{expected}, got #{status.exitstatus}: " \
            "#{output}#{errors}"
    end
    return output unless json

    payload = JSON.parse(output)
    abort 'CLI JSON schema changed' unless payload['schema_version'] == 1
    payload
  end
end

ArchUnitCLISmoke.run if $PROGRAM_NAME == __FILE__
