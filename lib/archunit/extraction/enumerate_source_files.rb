# frozen_string_literal: true

require 'find'
require 'pathname'
require_relative '../error/technical_error'
require_relative '../error/user_error'

module ArchUnit
  # Ruby-specific project discovery and source extraction.
  module Extraction
    DEFAULT_EXCLUDED_DIRECTORIES = %w[
      .bundle
      .cache
      .git
      .hg
      .ruby-lsp
      .svn
      .yardoc
      build
      coverage
      dist
      log
      node_modules
      pkg
      tmp
      vendor
    ].freeze

    module_function

    def enumerate_source_files(project_root, exclude_patterns: nil)
      root = source_root(project_root)
      patterns = resolve_exclude_patterns(exclude_patterns)
      source_files_under(root, patterns).sort.freeze
    rescue UserError, TechnicalError
      raise
    rescue SystemCallError => e
      raise TechnicalError, "could not enumerate Ruby source files: #{e.message}"
    end

    def source_files_under(root, exclude_patterns)
      Find.find(root.to_s).filter_map do |entry|
        if File.directory?(entry)
          Find.prune if excluded_path?(entry, root, exclude_patterns)
          next
        end

        if ruby_source_file?(entry) && !excluded_path?(entry, root, exclude_patterns)
          relative_identifier(entry, root).freeze
        end
      end
    end
    private_class_method :source_files_under

    def resolve_exclude_patterns(value)
      patterns = value.nil? ? DEFAULT_EXCLUDED_DIRECTORIES : value
      validate_exclude_patterns(patterns)

      normalized = patterns.map { |pattern| normalize_exclude_pattern(pattern) }
      raise_invalid_exclude_patterns if normalized.any?(&:empty?)

      normalized.uniq.freeze
    end
    private_class_method :resolve_exclude_patterns

    def validate_exclude_patterns(patterns)
      return if patterns.is_a?(Array) && patterns.all? { |pattern| valid_exclude_pattern?(pattern) }

      raise_invalid_exclude_patterns
    end
    private_class_method :validate_exclude_patterns

    def raise_invalid_exclude_patterns
      raise UserError, 'exclude_patterns must be an Array of non-empty Strings'
    end
    private_class_method :raise_invalid_exclude_patterns

    def valid_exclude_pattern?(pattern)
      pattern.is_a?(String) && !pattern.empty?
    end
    private_class_method :valid_exclude_pattern?

    def normalize_exclude_pattern(pattern)
      pattern.tr('\\', '/').delete_prefix('./').delete_suffix('/').freeze
    end
    private_class_method :normalize_exclude_pattern

    def ruby_source_file?(entry)
      File.file?(entry) && File.extname(entry) == '.rb'
    end
    private_class_method :ruby_source_file?

    def source_root(value)
      value = value.to_path if value.respond_to?(:to_path)
      unless value.is_a?(String) && !value.empty?
        raise UserError, 'project_root must be a non-empty path'
      end

      root = Pathname.new(value).expand_path
      raise UserError, 'project_root must be an existing directory' unless root.directory?

      root.realpath
    end
    private_class_method :source_root

    def excluded_path?(entry, root, exclude_patterns)
      return false if entry == root.to_s

      relative = relative_identifier(entry, root)
      exclude_patterns.any? do |pattern|
        exclude_pattern_matches?(pattern, relative, File.basename(entry))
      end
    end
    private_class_method :excluded_path?

    def exclude_pattern_matches?(pattern, relative, basename)
      flags = File::FNM_DOTMATCH | File::FNM_PATHNAME
      anchored = pattern.start_with?('/')
      candidate = pattern.delete_prefix('/')
      target = anchored || candidate.include?('/') ? relative : basename

      File.fnmatch?(candidate, target, flags)
    end
    private_class_method :exclude_pattern_matches?

    def relative_identifier(entry, root)
      Pathname.new(entry).relative_path_from(root).to_s.tr('\\', '/')
    end
    private_class_method :relative_identifier
  end
end
