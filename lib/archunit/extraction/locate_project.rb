# frozen_string_literal: true

require 'pathname'
require_relative '../error/technical_error'
require_relative '../error/user_error'

module ArchUnit
  # Ruby-specific project discovery and source extraction.
  module Extraction
    module_function

    def locate_project(locator = nil, working_directory: Dir.pwd)
      working_root = existing_directory(working_directory, :working_directory)
      root = project_root(locator, working_root)
      normalize_path(root.realpath)
    rescue UserError, TechnicalError
      raise
    rescue SystemCallError => e
      raise TechnicalError, "could not locate project: #{e.message}"
    end

    def project_root(locator, working_root)
      return detected_project_root(working_root) || working_root if locator.nil?

      explicit_project_root(locator, working_root)
    end
    private_class_method :project_root

    def explicit_project_root(locator, working_root)
      path = pathname(locator, :locator)
      path = working_root.join(path) unless path.absolute?

      return path.realpath if path.directory?
      return path.dirname.realpath if path.file? && project_marker_file?(path)

      raise UserError, 'project locator must be a directory, Gemfile, or .gemspec file'
    end
    private_class_method :explicit_project_root

    def detected_project_root(working_root)
      working_root.ascend.find { |directory| project_marker?(directory) }
    end
    private_class_method :detected_project_root

    def project_marker?(directory)
      directory.join('Gemfile').file? || directory.children.any? do |entry|
        entry.file? && entry.extname == '.gemspec'
      end
    end
    private_class_method :project_marker?

    def project_marker_file?(path)
      path.basename.to_s == 'Gemfile' || path.extname == '.gemspec'
    end
    private_class_method :project_marker_file?

    def existing_directory(value, attribute)
      path = pathname(value, attribute).expand_path
      raise UserError, "#{attribute} must be an existing directory" unless path.directory?

      path.realpath
    end
    private_class_method :existing_directory

    def pathname(value, attribute)
      value = value.to_path if value.respond_to?(:to_path)
      unless value.is_a?(String) && !value.empty?
        raise UserError, "#{attribute} must be a non-empty path"
      end

      Pathname.new(value)
    end
    private_class_method :pathname

    def normalize_path(path)
      path.to_s.tr('\\', '/')
    end
    private_class_method :normalize_path
  end
end
