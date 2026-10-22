# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'
require 'yard'

RSpec::Core::RakeTask.new(:spec)
RuboCop::RakeTask.new(:rubocop)

desc 'Validate version, changelog, and local-gem lock consistency'
task :release_metadata do
  ruby 'scripts/check_release_metadata.rb'
end

desc 'Refresh advisories and scan locked development/runtime dependencies'
task :security do
  ruby 'scripts/check_dependency_security.rb'
end

desc 'Build the GitHub Pages documentation site'
task :docs do
  sh 'yard doc'
  ruby 'scripts/prepare_docs.rb'
  ruby 'scripts/check_docs.rb'
end

namespace :benchmark do
  desc 'Profile cold and warm extraction on a deterministic synthetic monorepo'
  task :extraction do
    ruby 'benchmark/extraction.rb'
  end
end

task default: %i[release_metadata spec rubocop]
