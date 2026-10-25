# frozen_string_literal: true

require 'digest'
require 'open3'
require 'pathname'
require_relative 'extraction'

# Static analysis only. Never install a corpus's gems or load its application code.
module RealWorldCanary
  MANIFEST = File.expand_path('canary/projects.json', __dir__)
  MODES = %i[imports imports_and_constants].freeze

  # Compares pinned graph semantics and public rule behavior while collecting performance evidence.
  class Runner
    def initialize(root:, project:)
      @root = File.realpath(root)
      @project = project
    end

    def run(record: false)
      verify_checkout
      @source_root = library_root
      modes = MODES.to_h { |mode| [mode, check_mode(mode, record)] }
      { repository: @project.fetch('repository'), revision: @project.fetch('revision'),
        source_directory: 'lib',
        archunit_version: ArchUnit::VERSION, baseline_verified: !record, modes: }
    ensure
      ArchUnit.clear_graph_cache
    end

    private

    def library_root
      path = File.realpath(File.join(@root, 'lib'))
      relative = Pathname.new(path).relative_path_from(Pathname.new(@root)).to_s.tr('\\', '/')
      if relative == '..' || relative.start_with?('../')
        raise 'Library source directory must stay inside the corpus'
      end

      path
    end

    def verify_checkout
      expected = @project.fetch('revision')
      raise 'Canary requires full immutable commit hashes' unless expected.match?(/\A\h{40}\z/)
      raise 'Corpus revision does not match pin' unless git('rev-parse', 'HEAD') == expected
      return if git('status', '--porcelain', '--untracked-files=normal', '--', 'lib').empty?

      raise 'Corpus library source must be clean; do not install or generate files inside lib'
    end

    def git(*)
      stdout, stderr, status = Open3.capture3(
        { 'GIT_OPTIONAL_LOCKS' => '0' }, 'git', '-C', @root, *
      )
      raise "Could not inspect corpus checkout: #{stderr.strip}" unless status.success?

      stdout.strip
    end

    def check_mode(mode, record)
      configuration = { dependency_analysis: mode, max_cold_seconds: 120, max_warm_seconds: 5 }
      performance = ExtractionBenchmark::Runner.new(@source_root, configuration).run
      raise 'Warm analysis did not reuse the same graph' unless performance[:graph_cache_reused]

      options = ArchUnit::CheckOptions.new(dependency_analysis: mode)
      graph = ArchUnit::Extraction.extract_graph(@source_root, options:)
      observed = RealWorldCanary.snapshot(graph)
      verify_baseline(mode, observed) unless record
      verify_rules(options)
      { snapshot: observed, performance:, passing_rule: true, forbidden_rule_violations: 1 }
    end

    def verify_baseline(mode, observed)
      expected = @project.fetch('modes').fetch(mode.to_s)
      return if expected == observed.transform_keys(&:to_s)

      raise "#{mode} graph changed: expected #{expected.inspect}, observed #{observed.inspect}"
    end

    def verify_rules(options)
      witness = @project.fetch('witness')
      scope = ArchUnit.project_files(@source_root).in_file(witness.fetch('source'))
      ArchUnit.assert_passes(scope.should.depend_on_files.in_path(/\.rb\z/), options)
      verify_forbidden(forbidden_rule(scope, witness), options)
    end

    def forbidden_rule(scope, witness)
      scope.should_not.depend_on_files.in_path(
        /\A#{Regexp.escape(witness.fetch('target'))}\z/
      ).because('Canary must expose this known cross-file dependency')
    end

    def verify_forbidden(rule, options)
      violations = rule.check(options)
      unless violations.one? && violations.first.is_a?(ArchUnit::FileDependencyViolation)
        raise "Expected one known forbidden dependency, got #{violations.length}"
      end

      validate_assertion_failure(rule, options)
    end

    def validate_assertion_failure(rule, options)
      ArchUnit.assert_passes(rule, options)
      raise 'The forbidden architecture assertion unexpectedly passed'
    rescue ArchUnit::AssertionFailure => e
      raise 'Failure omitted rule rationale' unless e.message.include?(rule.rationale)
    end
  end

  module_function

  def snapshot(graph)
    sources = graph.map(&:source).uniq.sort
    pairs = internal_pairs(graph)
    { file_count: sources.length, internal_dependencies: pairs.length,
      external_dependencies: graph.count(&:external),
      internal_graph_sha256: Digest::SHA256.hexdigest(JSON.generate([sources, pairs])) }
  end

  def internal_pairs(graph)
    graph.filter_map do |edge|
      next if edge.external || edge.source == edge.target

      [edge.source, edge.target, edge.import_kinds.map(&:to_s).sort]
    end.sort
  end

  def execute(arguments)
    options = parse_options(arguments)
    project = load_project(options)
    result = Runner.new(root: options.fetch(:root), project:).run(record: options[:record])
    emit_result(options, result)
  rescue StandardError => e
    emit_error(options, e)
  end

  def load_project(options)
    projects = JSON.parse(File.read(options[:manifest])).fetch('projects')
    projects.fetch(options.fetch(:project))
  end

  def emit_result(options, result)
    payload = JSON.pretty_generate(result)
    ExtractionBenchmark.write_payload(options[:output], payload)
    puts payload
    0
  end

  def emit_error(options, error)
    payload = JSON.pretty_generate(error: "#{error.class}: #{error.message}")
    ExtractionBenchmark.write_payload(options[:output], payload) if options
    warn error.message
    1
  end

  def parse_options(arguments)
    options = { manifest: MANIFEST, output: nil, record: false }
    option_parser(options).parse!(arguments)
    raise ArgumentError, 'Unexpected positional arguments' unless arguments.empty?

    options
  end

  def option_parser(options)
    OptionParser.new do |parser|
      parser.on('--project NAME') { |value| options[:project] = value }
      parser.on('--root PATH') { |value| options[:root] = value }
      parser.on('--manifest PATH') { |value| options[:manifest] = value }
      parser.on('--output PATH') { |value| options[:output] = value }
      parser.on('--record', 'Observe proposed baselines; never edits the manifest') do
        options[:record] = true
      end
    end
  end
end

exit RealWorldCanary.execute(ARGV) if $PROGRAM_NAME == __FILE__
