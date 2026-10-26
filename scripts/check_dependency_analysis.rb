# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'
require 'archunit'

def verify_rationale(rule)
  explanation = 'Keep retrieval behind the API boundary'
  ArchUnit.assert_passes(rule.because(explanation))
  abort 'explained rule unexpectedly passed'
rescue ArchUnit::AssertionFailure => e
  abort 'rationale missing or repeated' unless e.message.scan(explanation).length == 1
end

def verify_project_exclusions(root, rule)
  File.write(File.join(root, '.archignore'), "app/retrieval/\n")
  abort 'ignore configuration did not refresh graph' unless rule.check.empty?

  remaining = ArchUnit.metrics(root).count.classes.measure.map { |item| item.subject.path }
  abort 'ignored file remained in metrics' unless remaining == ['app/api/request.rb']
end

def reject_malformed_source(rule)
  rule.check
  abort 'malformed source unexpectedly passed'
rescue ArchUnit::SourceParseError => e
  diagnostic = e.diagnostics.first
  abort 'parser location missing' unless diagnostic.path.end_with?('request.rb') &&
                                         diagnostic.line.positive? && diagnostic.column.positive?
end

def verify_parse_diagnostics(request, rule)
  File.write(request, "class Broken <\n")
  ArchUnit.clear_graph_cache
  reject_malformed_source(rule)
  File.write(request, "path = '../retrieval/store'\nrequire_relative path\n")
  ArchUnit.clear_graph_cache
end

def verify_rule_extensions(root, request, rule)
  verify_rationale(rule)
  verify_parse_diagnostics(request, rule)
  verify_project_exclusions(root, rule)
end

# Also run after installing the built gem, outside Bundler's source checkout.
Dir.mktmpdir('archunit-installed-analysis') do |root|
  File.write(File.join(root, 'Gemfile'), "raise 'must never execute project source'\n")
  %w[api retrieval].each { |name| FileUtils.mkdir_p(File.join(root, 'app', name)) }
  request = File.join(root, 'app/api/request.rb')
  File.write(File.join(root, 'app/retrieval/store.rb'), 'module Retrieval; class Store; end; end')
  File.write(request, 'module Api; class Request; Retrieval::Store.new; end; end')
  options = ArchUnit::CheckOptions.new(dependency_analysis: :imports_and_constants)
  rule = ArchUnit.project_files(root).in_path('app/api/**')
                 .should_not.depend_on_files.in_path('app/retrieval/**')
  abort 'import-only mode changed' unless rule.check.empty?
  abort 'constant dependency missing' unless rule.check(options).length == 1
  allowed = ArchUnit.project_files(root).in_path('app/api/**')
                    .should.depend_on_files.in_path('app/retrieval/**')
  ArchUnit.assert_passes(allowed, options)
  payload = JSON.parse(ArchUnit.project_graph(root).with_check_options(options).to_json)
  evidence = payload.fetch('edges').first.fetch('evidence').first
  abort 'constant evidence missing' unless evidence['name'] == 'Retrieval::Store'

  File.write(request, "path = '../retrieval/store'\nrequire_relative path\n")
  refreshed = ArchUnit::CheckOptions.new(clear_cache: true)
  abort 'local-string dependency missing' unless rule.check(refreshed).length == 1
  ArchUnit.assert_passes(allowed)

  verify_rule_extensions(root, request, rule)
  puts 'Installed dependency analysis, rule rationale, and project exclusions passed.'
ensure
  ArchUnit.clear_graph_cache
end
