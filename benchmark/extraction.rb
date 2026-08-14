# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'objspace'
require 'optparse'
require 'tmpdir'
require_relative '../lib/archunit'

# Reproducible cold/warm extraction benchmark and synthetic multi-gem corpus generator.
module ExtractionBenchmark
  DEFAULTS = {
    files: 1_000,
    gems: 10,
    imports_per_file: 3,
    max_cold_seconds: nil,
    max_warm_seconds: nil,
    output: nil
  }.freeze

  # Deterministic multi-gem Ruby corpus with both repeated and cross-gem requires.
  class Corpus
    attr_reader :root, :file_count, :gem_count, :imports_per_file

    def initialize(root, file_count:, gem_count:, imports_per_file:)
      @root = root
      @file_count = positive_integer(file_count, :files)
      @gem_count = positive_integer(gem_count, :gems)
      @imports_per_file = non_negative_integer(imports_per_file, :imports_per_file)
    end

    def generate
      gem_count.times { |index| write_gemspec(index) }
      file_count.times { |index| write_source(index) }
      write('packages/gem_00/lib/shared/common.rb', "# shared benchmark dependency\n")
      root
    end

    private

    def positive_integer(value, name)
      return value if value.is_a?(Integer) && value.positive?

      raise ArgumentError, "#{name} must be a positive Integer"
    end

    def non_negative_integer(value, name)
      return value if value.is_a?(Integer) && !value.negative?

      raise ArgumentError, "#{name} must be a non-negative Integer"
    end

    def write_gemspec(index)
      name = gem_name(index)
      write("packages/#{name}/#{name}.gemspec", "raise 'benchmark gemspec executed'\n")
    end

    def write_source(index)
      dependencies = dependency_features(index)
      contents = dependencies.map { |feature| "require '#{feature}'" }.join("\n")
      contents = '# isolated benchmark file' if contents.empty?
      write(source_path(index), "#{contents}\n")
    end

    def dependency_features(index)
      return [] if imports_per_file.zero?

      unique_count = imports_per_file - 1
      ['shared/common'] + Array.new(unique_count) do |offset|
        feature_name((index + offset + 1) % file_count)
      end
    end

    def source_path(index)
      gem = gem_name(index % gem_count)
      "packages/#{gem}/lib/#{feature_name(index)}.rb"
    end

    def feature_name(index)
      gem = gem_name(index % gem_count)
      "#{gem}/file_#{format('%05d', index)}"
    end

    def gem_name(index)
      "gem_#{format('%02d', index)}"
    end

    def write(relative_path, contents)
      path = File.join(root, relative_path)
      FileUtils.mkdir_p(File.dirname(path))
      File.binwrite(path, contents)
    end
  end

  # Runs one cold graph build and one same-process graph-cache lookup.
  class Runner
    RunValues = Data.define(
      :cold_graph, :cold_profile, :warm_graph, :warm_profile, :before, :after_cold
    )
    private_constant :RunValues

    def initialize(root, configuration)
      @root = root
      @configuration = configuration
    end

    def run
      ArchUnit.clear_graph_cache
      values = collect_values
      result = benchmark_result(values)
      enforce_thresholds(result)
      result
    end

    private

    def collect_values
      GC.start
      before = memory_snapshot
      cold_graph, cold_profile = extract_profiled
      after_cold = memory_snapshot
      warm_graph, warm_profile = extract_profiled
      RunValues.new(
        cold_graph:, cold_profile:, warm_graph:, warm_profile:, before:, after_cold:
      )
    end

    def extract_profiled
      profile = ArchUnit::Extraction::ExtractionProfile.new
      graph = ArchUnit::Extraction.extract_graph(@root, profile:)
      [graph, profile]
    end

    def benchmark_result(values)
      {
        corpus: @configuration.slice(:files, :gems, :imports_per_file),
        graph_edges: values.cold_graph.length,
        graph_cache_reused: values.cold_graph.equal?(values.warm_graph),
        cold: values.cold_profile.to_h.merge(memory_delta(values.before, values.after_cold)),
        warm: values.warm_profile.to_h,
        runtime: { ruby: RUBY_VERSION, platform: RUBY_PLATFORM }
      }
    end

    def memory_snapshot
      {
        ruby_heap_bytes: ObjectSpace.memsize_of_all,
        heap_live_slots: GC.stat(:heap_live_slots),
        process_peak_rss_kb: linux_peak_rss_kb
      }
    end

    def linux_peak_rss_kb
      return unless File.file?('/proc/self/status')

      match = File.read('/proc/self/status').match(/^VmHWM:\s+(\d+)\s+kB$/)
      match && Integer(match[1], 10)
    end

    def memory_delta(before, after)
      {
        memory: after,
        memory_growth: {
          ruby_heap_bytes: after[:ruby_heap_bytes] - before[:ruby_heap_bytes],
          heap_live_slots: after[:heap_live_slots] - before[:heap_live_slots]
        }
      }
    end

    def enforce_thresholds(result)
      check_threshold(result.dig(:cold, :stage_seconds, :total), :max_cold_seconds)
      check_threshold(result.dig(:warm, :stage_seconds, :total), :max_warm_seconds)
    end

    def check_threshold(actual, option)
      maximum = @configuration.fetch(option)
      return unless maximum && actual > maximum

      raise "#{option} exceeded: #{actual.round(3)}s > #{maximum}s"
    end
  end

  module_function

  def parse_options(arguments)
    options = DEFAULTS.dup
    parser = option_parser(options)
    parser.parse!(arguments)
    options
  end

  def option_parser(options)
    OptionParser.new do |parser|
      parser.banner = 'Usage: bundle exec ruby benchmark/extraction.rb [options]'
      configure_corpus_options(parser, options)
      configure_threshold_options(parser, options)
      parser.on('--output PATH', String) { |value| options[:output] = value }
    end
  end

  def configure_corpus_options(parser, options)
    parser.on('--files N', Integer) { |value| options[:files] = value }
    parser.on('--gems N', Integer) { |value| options[:gems] = value }
    parser.on('--imports-per-file N', Integer) { |value| options[:imports_per_file] = value }
  end

  def configure_threshold_options(parser, options)
    parser.on('--max-cold-seconds N', Float) { |value| options[:max_cold_seconds] = value }
    parser.on('--max-warm-seconds N', Float) { |value| options[:max_warm_seconds] = value }
  end

  def execute(arguments)
    options = parse_options(arguments)
    Dir.mktmpdir('archunit-extraction-benchmark') do |directory|
      run_in(directory, options)
    end
  end

  def run_in(directory, options)
    Corpus.new(
      directory,
      file_count: options.fetch(:files),
      gem_count: options.fetch(:gems),
      imports_per_file: options.fetch(:imports_per_file)
    ).generate
    payload = JSON.pretty_generate(Runner.new(directory, options).run)
    write_payload(options[:output], payload)
    puts payload
  end

  def write_payload(output, payload)
    return unless output

    path = File.expand_path(output)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, payload)
  end
end

ExtractionBenchmark.execute(ARGV) if $PROGRAM_NAME == __FILE__
