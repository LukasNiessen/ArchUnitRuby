# frozen_string_literal: true

require 'fileutils'
require 'pathname'
require 'tmpdir'

RSpec.describe ArchUnit::Extraction, 'profiling' do
  around do |example|
    Dir.mktmpdir('archunit-profile') do |directory|
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
  end

  it 'profiles every cold stage and reuses repeated feature resolutions' do
    create_file('lib/first.rb', "require 'shared'\n")
    create_file('lib/second.rb', "require 'shared'\n")
    create_file('lib/shared.rb')
    profile = ArchUnit::Extraction::ExtractionProfile.new

    graph = described_class.extract_graph(@project_root, profile:)

    expect(graph.length).to eq(5)
    expect(profile).not_to be_cache_hit
    expect(profile.counters).to include(
      source_files: 3,
      imports: 2,
      resolution_cache_hits: 1,
      resolution_cache_misses: 1,
      raw_edges: 5,
      merged_edges: 5
    )
    expect(profile.stage_seconds.values).to all(be >= 0.0)
    expect(profile.stage_seconds.values_at(:file_read, :prism_parse, :target_resolution))
      .to all(be_positive)
  end

  it 'marks a warm extraction without repeating cold pipeline counters' do
    create_file('lib/source.rb')
    described_class.extract_graph(@project_root)
    profile = ArchUnit::Extraction::ExtractionProfile.new

    described_class.extract_graph(@project_root, profile:)

    expect(profile).to be_cache_hit
    expect(profile.counters.values).to all(be_zero)
    expect(profile.stage_seconds.fetch(:total)).to be_positive
  end

  it 'rejects unrelated profile values' do
    create_file('lib/source.rb')

    expect { described_class.extract_graph(@project_root, profile: Object.new) }
      .to raise_error(ArgumentError, /ExtractionProfile/)
  end
end
