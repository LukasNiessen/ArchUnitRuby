# frozen_string_literal: true

require 'tmpdir'
require_relative '../../benchmark/extraction'

RSpec.describe ExtractionBenchmark do
  around do |example|
    Dir.mktmpdir('archunit-benchmark-spec') do |root|
      @root = File.realpath(root)
      example.run
    ensure
      ArchUnit.clear_graph_cache
    end
  end

  def corpus_configuration(**overrides)
    { file_count: 6, gem_count: 2, imports_per_file: 3 }.merge(overrides)
  end

  it 'generates deterministic cross-gem imports without executing gemspecs' do
    corpus = described_class::Corpus.new(@root, **corpus_configuration)
    expect(corpus.generate).to eq(@root)
    paths = Dir.glob(File.join(@root, '**/*.rb'))
    expect(paths.length).to eq(7)
    graph = ArchUnit::Extraction.extract_graph(@root)
    expect(graph.count { |edge| !edge.external && edge.source != edge.target }).to eq(18)
    expect(Dir.glob(File.join(@root, '**/*.gemspec')).length).to eq(2)
  end

  it 'generates isolated files when no imports are requested' do
    described_class::Corpus.new(@root, **corpus_configuration(imports_per_file: 0)).generate
    graph = ArchUnit::Extraction.extract_graph(@root)
    expect(graph.reject { |edge| edge.source == edge.target }).to be_empty
  end

  it 'rejects non-positive corpus sizes and negative import counts' do
    invalid = [{ file_count: 0 }, { file_count: '6' }, { gem_count: -1 }, { imports_per_file: -1 }]
    invalid.each do |bad|
      expect do
        described_class::Corpus.new(@root, **corpus_configuration(**bad))
      end.to raise_error(ArgumentError)
    end
  end

  it 'runs the CLI in a temporary corpus and writes a cache and performance report' do
    output = File.join(@root, 'reports/benchmark.json')
    arguments = %w[--files 6 --gems 2 --imports-per-file 0 --constants
                   --max-cold-seconds 120 --max-warm-seconds 5] + ['--output', output]
    expect { described_class.execute(arguments) }.to output(/graph_cache_reused/).to_stdout
    report = JSON.parse(File.read(output))
    expect(report).to include('graph_cache_reused' => true)
    expect(report.fetch('corpus')).to include('dependency_analysis' => 'imports_and_constants')
    expect(report.dig('cold', 'memory', 'ruby_heap_bytes')).to be_positive
  end

  it 'supports an output-free run without threshold limits' do
    configuration = described_class::DEFAULTS.merge(files: 2, gems: 1, imports_per_file: 1)
    expect do
      described_class.run_in(@root, configuration)
    end.to output(/graph_cache_reused/).to_stdout
  end

  it 'fails when a configured cold or warm time budget is exceeded' do
    described_class::Corpus.new(@root, **corpus_configuration).generate
    %i[max_cold_seconds max_warm_seconds].each do |threshold|
      configuration = described_class::DEFAULTS.merge(threshold => -1)
      runner = described_class::Runner.new(@root, configuration)
      expect { runner.run }.to raise_error(/#{threshold} exceeded/)
    end
  end

  it 'parses optional Linux peak memory without assuming the host has procfs' do
    runner = described_class::Runner.new(@root, described_class::DEFAULTS)
    allow(File).to receive(:file?).and_call_original
    allow(File).to receive(:file?).with('/proc/self/status').and_return(true)
    allow(File).to receive(:read).with('/proc/self/status').and_return("VmHWM: 1234 kB\n")
    expect(runner.send(:linux_peak_rss_kb)).to eq(1234)
    allow(File).to receive(:read).with('/proc/self/status').and_return("Name: ruby\n")
    expect(runner.send(:linux_peak_rss_kb)).to be_nil
    allow(File).to receive(:file?).with('/proc/self/status').and_return(false)
    expect(runner.send(:linux_peak_rss_kb)).to be_nil
  end
end
