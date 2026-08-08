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

    def enumerate_source_files(project_root)
      root = source_root(project_root)
      source_files_under(root).sort.freeze
    rescue UserError, TechnicalError
      raise
    rescue SystemCallError => e
      raise TechnicalError, "could not enumerate Ruby source files: #{e.message}"
    end

    def source_files_under(root)
      Find.find(root.to_s).filter_map do |entry|
        if File.directory?(entry)
          Find.prune if excluded_directory?(entry, root)
          next
        end

        relative_identifier(entry, root).freeze if ruby_source_file?(entry)
      end
    end
    private_class_method :source_files_under

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

    def excluded_directory?(entry, root)
      entry != root.to_s && DEFAULT_EXCLUDED_DIRECTORIES.include?(File.basename(entry))
    end
    private_class_method :excluded_directory?

    def relative_identifier(entry, root)
      Pathname.new(entry).relative_path_from(root).to_s.tr('\\', '/')
    end
    private_class_method :relative_identifier
  end
end
