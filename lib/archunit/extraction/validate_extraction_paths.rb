# frozen_string_literal: true

require 'pathname'
require_relative '../error/user_error'

module ArchUnit
  module Extraction
    # Validates public extractor paths before the trusted internal pipeline runs.
    module ExtractionPaths
      module_function

      def source_file(value)
        path = extraction_path(value, 'source_file')
        raise UserError, 'source_file must be an existing file' unless path.file?

        path
      end

      def project_root(value)
        path = extraction_path(value, 'project_root')
        raise UserError, 'project_root must be an existing directory' unless path.directory?

        path.realpath
      end

      def extraction_path(value, attribute)
        value = value.to_path if value.respond_to?(:to_path)
        unless value.is_a?(String) && !value.empty?
          raise UserError, "#{attribute} must be a non-empty path"
        end

        Pathname.new(value).expand_path
      end
      private_class_method :extraction_path
    end
  end
end
