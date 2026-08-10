# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe 'projection integration' do
  around do |example|
    Dir.mktmpdir('archunit-projection') do |directory|
      @project_root = Pathname.new(directory).realpath
      ArchUnit.clear_graph_cache
      example.run
      ArchUnit.clear_graph_cache
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  it 'projects an extracted graph to nodes while retaining an isolated source' do
    create_file('lib/api/controller.rb', "require_relative '../domain/service'\n")
    create_file('lib/domain/service.rb')
    create_file('lib/isolated.rb')
    graph = ArchUnit::Extraction.extract_graph(@project_root)

    nodes = ArchUnit::Common::Projection.project_to_nodes(graph)

    expect(nodes.map(&:label)).to contain_exactly(
      'lib/api/controller.rb', 'lib/domain/service.rb', 'lib/isolated.rb'
    )
    isolated = nodes.find { |node| node.label == 'lib/isolated.rb' }
    expect(isolated.incoming).to be_empty
    expect(isolated.outgoing).to be_empty
  end

  it 'relabels and cumulates extracted dependencies into folder-level evidence' do
    create_file('lib/api/first.rb', "require_relative '../domain/service'\n")
    create_file('lib/api/second.rb', "require_relative '../domain/service'\n")
    create_file('lib/domain/service.rb')
    graph = ArchUnit::Extraction.extract_graph(@project_root)

    projected = ArchUnit::Common::Projection.project_edges(graph) do |edge|
      next if edge.external || edge.source == edge.target

      ArchUnit::MappedEdge.new(
        source_label: edge.source.split('/')[1],
        target_label: edge.target.split('/')[1]
      )
    end

    expect(projected).to contain_exactly(
      ArchUnit::ProjectedEdge.new(
        source_label: 'api',
        target_label: 'domain',
        cumulated_edges: graph.reject { |edge| edge.source == edge.target }
      )
    )
  end
end
