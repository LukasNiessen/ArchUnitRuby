# frozen_string_literal: true

require 'archunit'
require 'fileutils'
require 'tmpdir'

# Also runs outside Bundler after installing the built gem in CI.
declarations = [
  'module Db; DEFAULT ||= 42; end',
  'module Db; end; Db::DEFAULT ||= 42',
  'module Db; end; ::Db::DEFAULT ||= 42'
].freeze
options = ArchUnit::CheckOptions.new(dependency_analysis: :imports_and_constants)
Dir.mktmpdir('archunit-installed-constant-writes') do |root|
  %w[api db].each { |folder| FileUtils.mkdir_p(File.join(root, 'app', folder)) }
  File.write(File.join(root, 'Gemfile'), "raise 'must not execute project source'\n")
  File.write(File.join(root, 'app/api/request.rb'), '::Db::DEFAULT')
  scope = ArchUnit.project_files(root).in_path('app/api/**')
  forbidden = scope.should_not.depend_on_files.in_path('app/db/**')
  allowed = scope.should.depend_on_files.in_path('app/db/**')
  declarations.each do |declaration|
    File.write(File.join(root, 'app/db/settings.rb'), declaration)
    ArchUnit.clear_graph_cache
    violations = forbidden.check(options)
    abort 'conditional constant dependency missing' unless violations.length == 1
    edge = violations.first.dependency.cumulated_edges.first
    abort 'constant definition evidence missing' unless edge.evidence.first.target_line_number == 1
    abort 'import-only behavior changed' unless forbidden.check.empty?
    ArchUnit.assert_passes(allowed, options)
  end
  puts 'Conditional constant definitions passed in the installed-gem API.'
ensure
  ArchUnit.clear_graph_cache
end
