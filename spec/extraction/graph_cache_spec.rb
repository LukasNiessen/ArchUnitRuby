# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, 'graph cache' do
  around do |example|
    Dir.mktmpdir('archunit-cache') do |directory|
      @project_root = Pathname.new(directory).realpath
      described_class.clear_graph_cache
      example.run
      described_class.clear_graph_cache
    end
  end

  def create_file(relative_path, contents = '# fixture')
    path = @project_root.join(relative_path)
    FileUtils.mkdir_p(path.dirname)
    path.write(contents)
    path
  end

  it 'reuses the same immutable graph for equivalent extraction inputs' do
    create_file('lib/source.rb')

    first = described_class.extract_graph(@project_root)
    second = described_class.extract_graph(@project_root.to_s)

    expect(second).to equal(first)
  end

  it 'keys equivalent exclusion sets independently of order and duplicates' do
    create_file('lib/source.rb')
    first = described_class.extract_graph(
      @project_root, exclude_patterns: %w[vendor tmp vendor]
    )
    second = described_class.extract_graph(
      @project_root, exclude_patterns: %w[tmp vendor]
    )

    expect(second).to equal(first)
  end

  it 'uses distinct cache entries when exclusions change graph contents' do
    create_file('lib/source.rb')
    create_file('generated/hidden.rb')

    complete = described_class.extract_graph(@project_root, exclude_patterns: [])
    filtered = described_class.extract_graph(
      @project_root, exclude_patterns: ['generated']
    )

    expect(complete.map(&:source)).to include('generated/hidden.rb')
    expect(filtered.map(&:source)).not_to include('generated/hidden.rb')
    expect(filtered).not_to equal(complete)
  end

  it 'keeps cached results until explicitly invalidated' do
    create_file('lib/first.rb')
    first = described_class.extract_graph(@project_root)
    create_file('lib/second.rb')

    cached = described_class.extract_graph(@project_root)

    expect(cached).to equal(first)
    expect(cached.map(&:source)).not_to include('lib/second.rb')
  end

  it 'rebuilds the matching entry when clear_cache is set on CheckOptions' do
    create_file('lib/first.rb')
    first = described_class.extract_graph(@project_root)
    create_file('lib/second.rb')
    options = ArchUnit::CheckOptions.new(clear_cache: true)

    rebuilt = described_class.extract_graph(@project_root, options:)

    expect(rebuilt).not_to equal(first)
    expect(rebuilt.map(&:source)).to include('lib/second.rb')
  end

  it 'does not evict unrelated projects for per-call invalidation' do
    create_file('first/lib/source.rb')
    create_file('second/lib/source.rb')
    first_root = @project_root.join('first')
    second_root = @project_root.join('second')
    first_graph = described_class.extract_graph(first_root)
    second_graph = described_class.extract_graph(second_root)

    rebuilt = described_class.extract_graph(
      first_root, options: ArchUnit::CheckOptions.new(clear_cache: true)
    )

    expect(rebuilt).not_to equal(first_graph)
    expect(described_class.extract_graph(second_root)).to equal(second_graph)
  end

  it 'clears every entry through the public global escape hatch' do
    create_file('lib/source.rb')
    first = described_class.extract_graph(@project_root)

    expect(ArchUnit.clear_graph_cache).to be_nil
    expect(described_class.extract_graph(@project_root)).not_to equal(first)
  end

  it 'shares a cache entry across equivalent directory and marker locators' do
    gemfile = create_file('Gemfile')
    create_file('lib/source.rb')

    from_directory = described_class.extract_graph(@project_root)
    from_marker = described_class.extract_graph(gemfile)

    expect(from_marker).to equal(from_directory)
  end

  it 'does not let non-analysis check options fragment the cache' do
    create_file('lib/source.rb')
    first = described_class.extract_graph(@project_root)
    options = ArchUnit::CheckOptions.new(allow_empty_tests: true, logging: Object.new)

    expect(described_class.extract_graph(@project_root, options:)).to equal(first)
  end

  it 'serializes concurrent cache misses to one shared graph value' do
    create_file('lib/source.rb')

    graphs = Array.new(8) do
      Thread.new { described_class.extract_graph(@project_root) }
    end.map(&:value)

    expect(graphs.map(&:object_id).uniq.length).to eq(1)
  end
end
