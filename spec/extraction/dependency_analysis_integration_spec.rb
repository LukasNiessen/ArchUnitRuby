# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest'
require 'pathname'
require 'tmpdir'

RSpec.describe 'expanded dependency analysis through the public API' do
  let(:options) { ArchUnit::CheckOptions.new(dependency_analysis: :imports_and_constants) }

  around do |example|
    Dir.mktmpdir('archunit-dependency-analysis') do |directory|
      @root = Pathname.new(directory).realpath
      @root.join('Gemfile').write("raise 'Gemfile executed'")
      source('app/retrieval/store.rb', 'module Retrieval; class Store; end; end')
      source('app/api/request.rb', 'module Api; class Request; Retrieval::Store.new; end; end')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def source(path, contents)
    file = @root.join(path)
    FileUtils.mkdir_p(file.dirname)
    file.write(contents)
  end

  def file_rule(mood = :should_not)
    ArchUnit.project_files(@root).in_path('app/api/**')
            .public_send(mood).depend_on_files.in_path('app/retrieval/**')
  end

  it 'reports the forbidden dependency exactly once and accepts its permitted counterpart' do
    expect(file_rule.check).to be_empty
    expect(file_rule.check(options)).to contain_exactly(
      have_attributes(dependency: have_attributes(target_label: 'app/retrieval/store.rb'))
    )
    expect { ArchUnit.assert_passes(file_rule(:should), options) }.not_to raise_error
  end

  it 'recognizes the local-string reproducer through the default public file rules' do
    source('app/api/request.rb', "path = '../retrieval/store'\nrequire_relative path\n")

    expect(file_rule.check.length).to eq(1)
    expect(file_rule(:should)).to pass
    expect(file_rule.check(options).first.dependency.cumulated_edges.first).to have_attributes(
      import_kinds: [:require_relative],
      evidence: contain_exactly(have_attributes(line_number: 2, name: '../retrieval/store'))
    )
    expect(file_rule.check.first.dependency.cumulated_edges.first).to eq(
      ArchUnit::Edge.new(
        source: 'app/api/request.rb', target: 'app/retrieval/store.rb', external: false,
        import_kinds: [:require_relative]
      )
    )
  end

  it 'detects both a constant-only cycle and a local-string-only cycle' do
    source('app/retrieval/store.rb', 'module Retrieval; class Store; Api::Request.new; end; end')
    rule = ArchUnit.project_files(@root).should.have_no_cycles
    expect(rule.check).to be_empty
    expect(rule.check(options).length).to eq(1)

    source('app/api/request.rb', "path = '../retrieval/store'\nrequire_relative path\n")
    source('app/retrieval/store.rb', "path = '../api/request'\nrequire_relative path\n")
    expect(rule.check(ArchUnit::CheckOptions.new(clear_cache: true)).length).to eq(1)
  end

  it 'feeds identical constant edges into layer, slice, diagram, and graph consumers' do
    layers = ArchUnit.project_layers(@root)
                     .layer('api').defined_by('app/api/**')
                     .layer('retrieval').defined_by('app/retrieval/**')
                     .where_layer('api').may_not_depend_on_layers('retrieval')
    slices = ArchUnit.project_slices(@root).defined_by('app/(**)/')
    expect(layers.check(options).length).to eq(1)
    expect(slices.should_not.contain_dependency('api', 'retrieval').check(options).length).to eq(1)
    diagram = slices.to_plantuml(options)
    expect(diagram).to include('[api] --> [retrieval]')
    expect(slices.should.adhere_to_diagram(diagram).check(options)).to be_empty

    report = ArchUnit.project_graph(@root).with_check_options(options)
    payload = JSON.parse(report.to_json)
    expect(payload.fetch('edges')).to contain_exactly(
      include(
        'source' => 'app/api/request.rb', 'target' => 'app/retrieval/store.rb',
        'import_kinds' => ['constant_reference'],
        'evidence' => [include('name' => 'Retrieval::Store', 'line_number' => 1)]
      )
    )
    expect(report.to_csv).to include('constant_reference')
    expect(report.to_mermaid).to include('-->')
  end

  it 'uses the same analysis through the RSpec and Minitest adapters' do
    allowed = file_rule(:should)
    expect(allowed).to pass(options)
    ArchUnit::Testing::MinitestAdapter.install!
    context = Class.new do
      include Minitest::Assertions

      attr_accessor :assertions
    end.new
    context.assertions = 0
    expect(context.assert_passes(allowed, options)).to be(true)
    expect { context.assert_passes(file_rule, options) }.to raise_error(Minitest::Assertion)

    source('app/api/request.rb', "path = '../retrieval/store'\nrequire_relative path\n")
    ArchUnit.clear_graph_cache
    expect(context.assert_passes(file_rule(:should))).to be(true)
    expect { context.assert_passes(file_rule) }.to raise_error(Minitest::Assertion)
  end

  it 'uses constant edges for coupling measurements and metric threshold checks' do
    metric = ArchUnit.metrics(@root).in_path('app/api/**').distance.instability

    expect(metric.measure.first.value).to eq(0.0)
    expect(metric.measure(options).first.value).to eq(1.0)
    expect(metric.should_be(1.0).check(options)).to be_empty
  end
end
