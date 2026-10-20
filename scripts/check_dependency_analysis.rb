# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'
require 'archunit'

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
  puts 'Installed dependency analysis: constant and local-string reproducers passed.'
ensure
  ArchUnit.clear_graph_cache
end
