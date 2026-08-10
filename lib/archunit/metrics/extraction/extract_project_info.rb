# frozen_string_literal: true

require 'pathname'
require 'prism'
require_relative '../../error/technical_error'
require_relative '../../extraction/enumerate_source_files'
require_relative '../../extraction/locate_project'
require_relative 'metric_info'
require_relative 'source_metrics_visitor'

module ArchUnit
  module Metrics
    # Ruby source extraction for numeric code metrics.
    module Extraction
      module_function

      def extract_project_info(project_locator = nil, exclude_patterns: nil)
        root = Pathname.new(ArchUnit::Extraction.locate_project(project_locator))
        files = ArchUnit::Extraction.enumerate_source_files(root, exclude_patterns:).map do |path|
          extract_file_info(root.join(path), relative_path: path)
        end
        ProjectInfo.new(project_root: root.to_s, files:)
      end

      def extract_file_info(source_file, relative_path: nil)
        path = source_path(source_file)
        identifier = (relative_path || path.basename.to_s).to_s.tr('\\', '/')
        source = path.read
        build_file_info(identifier, source)
      rescue SystemCallError => e
        raise TechnicalError, "could not extract Ruby source metrics: #{e.message}"
      end

      def build_file_info(identifier, source)
        parse_result = Prism.parse(source)
        visitor = SourceMetricsVisitor.new(identifier)
        visitor.visit(parse_result.value) if parse_result.success?
        FileInfo.new(
          path: identifier, lines_of_code: lines_of_code(source), **visitor_counts(visitor)
        )
      end
      private_class_method :build_file_info

      def visitor_counts(visitor)
        {
          statement_count: visitor.statement_count,
          import_count: visitor.import_count,
          class_count: visitor.class_count,
          function_count: visitor.function_count,
          class_infos: visitor.class_infos
        }
      end
      private_class_method :visitor_counts

      # rubocop:disable Metrics/MethodLength -- The state tracks Ruby's =begin/=end comments.
      def lines_of_code(source)
        in_block_comment = false
        source.each_line.count do |line|
          stripped = line.strip
          if stripped == '=begin'
            in_block_comment = true
            false
          elsif stripped == '=end' && in_block_comment
            in_block_comment = false
            false
          else
            !in_block_comment && !stripped.empty? && !stripped.start_with?('#')
          end
        end
      end
      # rubocop:enable Metrics/MethodLength
      private_class_method :lines_of_code

      def source_path(value)
        value = value.to_path if value.respond_to?(:to_path)
        unless value.is_a?(String) && !value.empty?
          raise ArgumentError, 'source_file must be a non-empty path'
        end

        path = Pathname.new(value).expand_path
        raise ArgumentError, 'source_file must be an existing file' unless path.file?

        path
      end
      private_class_method :source_path
    end
  end
end
