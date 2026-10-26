# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'tmpdir'

RSpec.describe 'constant-write dependency analysis' do
  let(:options) { ArchUnit::CheckOptions.new(dependency_analysis: :imports_and_constants) }

  around do |example|
    Dir.mktmpdir('archunit-constant-writes') do |directory|
      @root = File.realpath(directory)
      source('Gemfile', "raise 'must not execute'\n")
      source('app/api/request.rb', 'module Api; class Request; def call = ::Db::DEFAULT; end; end')
      ArchUnit.clear_graph_cache
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  def source(path, contents)
    file = File.join(@root, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, contents)
  end

  def rule(mood = :should_not)
    ArchUnit.project_files(@root).in_path('app/api/**')
            .public_send(mood).depend_on_files.in_path('app/db/**')
  end

  def edges(**keywords)
    ArchUnit::Extraction.extract_graph(@root, options:, **keywords).reject do |edge|
      edge.source == edge.target
    end
  end

  {
    lexical: 'module Db; DEFAULT ||= 42; end',
    qualified: 'module Db; end; Db::DEFAULT ||= 42',
    root_qualified: 'module Db; end; ::Db::DEFAULT ||= 42'
  }.each do |form, declaration|
    it "resolves #{form} ||= definitions through the public file rule without executing them" do
      source('app/db/settings.rb', "#{declaration}\nraise 'must not execute'\n")
      violations = rule.check(options)
      expect(violations.length).to eq(1)
      attributes = {
        source: 'app/api/request.rb', target: 'app/db/settings.rb',
        import_kinds: [:constant_reference],
        evidence: contain_exactly(have_attributes(name: '::Db::DEFAULT', target_line_number: 1))
      }
      expect(edges).to contain_exactly(have_attributes(attributes))
      ArchUnit.assert_passes(rule(:should), options)
      expect(rule.check).to be_empty
    end
  end

  it 'preserves nested lexical ownership instead of attributing a same-name root constant' do
    source('lib/root.rb', 'DEFAULT = 1')
    source('app/db/settings.rb', 'module Outer; module Db; DEFAULT ||= 42; end; end')
    source('app/api/request.rb', '::Outer::Db::DEFAULT')
    expect(edges).to contain_exactly(have_attributes(target: 'app/db/settings.rb'))
  end

  it 'visits right-hand dependencies and merges parallel import/reference evidence' do
    source('app/db/settings.rb', 'module Db; DEFAULT ||= ::Seed::VALUE; end')
    source('lib/seed.rb', 'module Seed; VALUE = 42; end')
    source('app/api/request.rb', "require_relative '../db/settings'\n::Db::DEFAULT\n")
    dependency = edges.find { |edge| edge.source == 'app/api/request.rb' }
    expect(dependency.import_kinds).to match_array(%i[require_relative constant_reference])
    expect(dependency.evidence.map(&:kind)).to match_array(%i[require_relative constant_reference])
    expect(edges).to include(have_attributes(source: 'app/db/settings.rb', target: 'lib/seed.rb'))
    expect(rule.check(options).length).to eq(1)
  end

  it 'treats multiple candidate definition files as ambiguous rather than selecting one' do
    %w[settings other].each do |name|
      source("app/db/#{name}.rb", 'module Db; DEFAULT ||= 42; end')
    end
    profile = ArchUnit::Extraction::ExtractionProfile.new
    expect(edges(profile:)).to be_empty
    expect(profile.counters.fetch(:ambiguous_constant_references)).to eq(1)
  end

  it 'refreshes changed conditional definitions only with the documented cache-clearing option' do
    source('app/db/settings.rb', 'module Db; DEFAULT ||= 42; end')
    expect(rule.check(options).length).to eq(1)
    source('app/db/settings.rb', 'module Db; OTHER ||= 42; end')
    expect(rule.check(options).length).to eq(1)
    expect(rule.check(options.with(clear_cache: true))).to be_empty
  end

  it 'does not invent declarations from update-only or unsupported multiple-assignment forms' do
    ['DEFAULT &&= 42', 'DEFAULT += 42', 'DEFAULT, OTHER = 1, 2'].each do |assignment|
      source('app/db/settings.rb', "module Db; #{assignment}; end")
      expect(rule.check(options.with(clear_cache: true))).to be_empty
    end
  end

  it 'shares the same conditional-definition edges with layers, slices, and JSON reports' do
    source('app/db/settings.rb', 'module Db; DEFAULT ||= 42; end')
    layers = ArchUnit.project_layers(@root)
                     .layer('api').defined_by('app/api/**')
                     .layer('db').defined_by('app/db/**')
                     .where_layer('api').may_not_depend_on_layers('db')
    slices = ArchUnit.project_slices(@root).defined_by('app/(**)/')
    expect(layers.check(options).length).to eq(1)
    expect(slices.should_not.contain_dependency('api', 'db').check(options).length).to eq(1)
    report = JSON.parse(ArchUnit.project_graph(@root).with_check_options(options).to_json)
    expect(report.fetch('edges').first.fetch('evidence').first.fetch('name')).to eq('::Db::DEFAULT')
  end
end
