# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, '.extract_graph' do
  around do |example|
    Dir.mktmpdir('archunit-graph') do |directory|
      @project_root = Pathname.new(directory).realpath
      example.run
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  def extract
    described_class.extract_graph(@project_root)
  end

  it 'emits a self-edge for every Ruby source, including isolated and malformed files' do
    create_file('lib/isolated.rb')
    create_file('lib/broken.rb', "def broken(\n")

    expect(extract).to contain_exactly(
      ArchUnit::Edge.new(
        source: 'lib/broken.rb', target: 'lib/broken.rb', external: false
      ),
      ArchUnit::Edge.new(
        source: 'lib/isolated.rb', target: 'lib/isolated.rb', external: false
      )
    )
  end

  it 'merges parallel internal edges and unions all import kinds' do
    create_file('lib/source.rb', <<~RUBY)
      require_relative 'target'
      require 'target'
      autoload :Target, 'target'
      load 'target.rb'
    RUBY
    create_file('lib/target.rb')

    dependency = extract.find do |edge|
      edge.source == 'lib/source.rb' && edge.target == 'lib/target.rb'
    end

    expect(dependency).to have_attributes(
      external: false,
      import_kinds: %i[require_relative require autoload load]
    )
    matching_edges = extract.select do |edge|
      edge.source == dependency.source && edge.target == dependency.target
    end
    expect(matching_edges.length).to eq(1)
  end

  it 'deduplicates repeated calls of the same import kind' do
    create_file('lib/source.rb', <<~RUBY)
      require_relative 'target'
      require_relative 'target'
    RUBY
    create_file('lib/target.rb')

    dependencies = extract.reject { |edge| edge.source == edge.target }

    expect(dependencies).to contain_exactly(
      ArchUnit::Edge.new(
        source: 'lib/source.rb',
        target: 'lib/target.rb',
        external: false,
        import_kinds: [:require_relative]
      )
    )
  end

  it 'merges a real self-dependency into the synthetic self-edge' do
    create_file('lib/source.rb', "require_relative 'source'\n")

    expect(extract).to contain_exactly(
      ArchUnit::Edge.new(
        source: 'lib/source.rb',
        target: 'lib/source.rb',
        external: false,
        import_kinds: [:require_relative]
      )
    )
  end

  it 'merges parallel external edges while retaining the raw module name' do
    create_file('lib/source.rb', <<~RUBY)
      require 'json'
      autoload :JSON, 'json'
    RUBY

    dependency = extract.find(&:external)

    expect(dependency).to have_attributes(
      source: 'lib/source.rb',
      target: 'json',
      import_kinds: %i[require autoload]
    )
  end

  it 'guarantees that every source-target pair is unique' do
    create_file('lib/first.rb', <<~RUBY)
      require_relative 'target'
      load 'target.rb'
    RUBY
    create_file('lib/second.rb', "require_relative 'target'\n")
    create_file('lib/target.rb')

    pairs = extract.map { |edge| [edge.source, edge.target] }

    expect(pairs.uniq).to eq(pairs)
  end

  it 'returns an immutable Graph value' do
    create_file('lib/source.rb')

    graph = extract

    expect(graph).to be_a(ArchUnit::Graph)
    expect(graph).to be_frozen
    expect(graph.edges).to be_frozen
  end

  it 'supports explicit marker locators and automatic project detection' do
    gemfile = create_file('Gemfile')
    create_file('lib/source.rb')
    nested = @project_root.join('lib/nested')
    FileUtils.mkdir_p(nested)

    expect(described_class.extract_graph(gemfile).map(&:source)).to include('lib/source.rb')
    expect(described_class.extract_graph(working_directory: nested).map(&:source))
      .to include('lib/source.rb')
  end
end
