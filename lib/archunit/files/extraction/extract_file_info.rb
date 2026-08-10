# frozen_string_literal: true

require 'pathname'
require_relative '../../error/technical_error'
require_relative 'file_info'

module ArchUnit
  module Files
    # Ruby-specific descriptive data extraction for file rules.
    module Extraction
      module_function

      def extract_file_info(project_root, relative_path)
        root = project_directory(project_root)
        identifier = normalized_identifier(relative_path)
        source_path = source_path_within(root, identifier)
        build_file_info(identifier, read_source(source_path))
      rescue TechnicalError
        raise
      rescue SystemCallError => e
        raise TechnicalError, "could not extract file information: #{e.message}"
      end

      def read_source(path)
        File.binread(path).force_encoding(Encoding::UTF_8).scrub
      end
      private_class_method :read_source

      def build_file_info(identifier, content)
        extension = File.extname(identifier)
        FileInfo.new(
          path: identifier,
          name: File.basename(identifier, extension),
          extension:,
          directory: directory_of(identifier),
          content:,
          lines_of_code: content.lines.count { |line| !line.strip.empty? }
        )
      end
      private_class_method :build_file_info

      def project_directory(value)
        value = value.to_path if value.respond_to?(:to_path)
        unless value.is_a?(String) && !value.empty?
          raise ArgumentError, 'project_root must be a non-empty path'
        end

        root = Pathname.new(value).expand_path
        raise TechnicalError, 'project_root must be an existing directory' unless root.directory?

        root.realpath
      end
      private_class_method :project_directory

      def normalized_identifier(value)
        unless value.is_a?(String) && !value.empty?
          raise ArgumentError, 'relative_path must be a non-empty String'
        end

        value.tr('\\', '/').freeze
      end
      private_class_method :normalized_identifier

      def source_path_within(root, identifier)
        path = root.join(identifier).cleanpath
        relative = path.relative_path_from(root).to_s.tr('\\', '/')
        if relative == '..' || relative.start_with?('../')
          raise TechnicalError, 'source file must be inside the project root'
        end
        raise TechnicalError, "source file does not exist: #{identifier}" unless path.file?

        path
      end
      private_class_method :source_path_within

      def directory_of(identifier)
        return '' unless identifier.include?('/')

        File.dirname(identifier).tr('\\', '/').freeze
      end
      private_class_method :directory_of
    end
  end
end
