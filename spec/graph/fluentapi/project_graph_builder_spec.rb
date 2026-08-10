# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::GraphReporting::FluentApi::ProjectGraphBuilder do
  around do |example|
    Dir.mktmpdir('archunit-project-graph') do |directory|
      @project_root = Pathname.new(directory).realpath
      @project_root.join('Gemfile').write('')
      create_file('lib/api.rb', "require_relative 'service'\nrequire 'json'\n")
      create_file('lib/service.rb', "require_relative 'model'\n")
      create_file('lib/model.rb')
      create_file('lib/orphan.rb')
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
  end

  it 'builds no graph until a snapshot terminal is called' do
    expect(ArchUnit::Extraction).not_to receive(:extract_graph)

    ArchUnit.project_graph(@project_root)
            .include_external_dependencies
            .focus_on('lib/**', 2)
            .reachable_from('lib/api.rb')
            .dependents_of('lib/model.rb')
            .collapse_to_folder_depth(1)
            .titled('Application')
  end

  it 'extracts a real project into one report snapshot and summary' do
    report = ArchUnit.project_graph(@project_root).titled('Fixture Architecture')
    snapshot = report.snapshot

    expect(snapshot.title).to eq('Fixture Architecture')
    expect(snapshot.nodes.map(&:label)).to contain_exactly(
      'lib/api.rb', 'lib/service.rb', 'lib/model.rb', 'lib/orphan.rb'
    )
    expect(snapshot.summary).to have_attributes(
      node_count: 4, edge_count: 2, raw_edge_count: 2, external_edge_count: 0
    )
    expect(report.summary).to eq(snapshot.summary)
  end

  it 'threads external, self, focus, traversal, collapse, and title options immutably' do
    base = ArchUnit.dependency_graph(@project_root)
    external = base.include_external_dependencies
    self_edges = external.include_self_dependencies
    focused = self_edges.focus_on('lib/api.rb', 0)
    reachable = focused.reachable_from('lib/service.rb')
    dependents = reachable.dependents_of('lib/model.rb')
    collapsed = dependents.collapse_by_pattern(%r{lib/([^/]+)\.rb}, '\\1')
    titled = collapsed.titled('Focused')

    expect(base.options.include_external_dependencies).to be(false)
    expect(external.options.include_external_dependencies).to be(true)
    expect(self_edges.options.include_self_dependencies).to be(true)
    expect(focused.options.focus_depth).to eq(0)
    expect(reachable.options.reachable_from).to be_a(ArchUnit::Filter)
    expect(dependents.options.dependents_of).to be_a(ArchUnit::Filter)
    expect(collapsed.options.collapse).to be_a(ArchUnit::PatternCollapse)
    expect(titled.options.title).to eq('Focused')
    expect([base, external, self_edges, focused, reachable, dependents, collapsed, titled])
      .to all(be_frozen)
  end

  it 'passes an immutable CheckOptions value to extraction unchanged' do
    check_options = ArchUnit::CheckOptions.new(clear_cache: true)
    report = ArchUnit.project_graph(@project_root).with_check_options(check_options)

    expect(ArchUnit::Extraction).to receive(:extract_graph)
      .with(@project_root.to_s, options: check_options).and_call_original
    report.snapshot
    expect(report.check_options).to equal(check_options)
  end

  it 'exposes equivalent public entry points and snapshot value aliases' do
    expect(ArchUnit).to respond_to(:project_graph, :dependency_graph)
    expect(ArchUnit.project_graph(@project_root)).to be_a(described_class)
    expect(ArchUnit::GraphReportSnapshot).to equal(
      ArchUnit::GraphReporting::Projection::GraphReportSnapshot
    )
    expect(ArchUnit::GraphSnapshotFactory).to equal(
      ArchUnit::GraphReporting::Projection::SnapshotFactory
    )
  end

  it 'renders and exports all six formats from the public builder' do
    report = ArchUnit.project_graph(@project_root).titled('Fixture Graph')

    Dir.mktmpdir('archunit-builder-exports') do |directory|
      ArchUnit::GraphRenderer::RENDERERS.each_key do |format|
        rendered = report.public_send("to_#{format}")
        path = Pathname.new(directory).join('reports', "fixture.#{format}")

        expect(rendered).to be_a(String)
        expect(rendered).not_to be_empty
        expect(report.public_send("export_as_#{format}", path)).to be_nil
        expect(path.binread.force_encoding(Encoding::UTF_8)).to eq(rendered)
      end
    end
  end

  it 'validates builder locators, check options, queries, and collapse modifiers' do
    expect { described_class.new(project_locator: Object.new) }
      .to raise_error(ArgumentError, /project_locator/)
    expect { described_class.new(options: Object.new) }
      .to raise_error(ArgumentError, /GraphQueryOptions/)
    expect { ArchUnit.project_graph.with_check_options(Object.new) }
      .to raise_error(ArgumentError, /CheckOptions/)
    expect { ArchUnit.project_graph.focus_on('lib/**', -1) }
      .to raise_error(ArgumentError, /non-negative/)
    expect { ArchUnit.project_graph.collapse_to_folder_depth(0) }
      .to raise_error(ArgumentError, /positive/)
    expect { ArchUnit.project_graph.collapse_by_pattern(Object.new) }
      .to raise_error(ArgumentError, /Regexp/)
    expect { ArchUnit.project_graph.titled('') }
      .to raise_error(ArgumentError, /title/)
  end
end
