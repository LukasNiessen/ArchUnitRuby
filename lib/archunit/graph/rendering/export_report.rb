# frozen_string_literal: true

require 'fileutils'

module ArchUnit
  module GraphReporting
    module Rendering
      # UTF-8 file export shared by every graph report format.
      module ExportReport
        module_function

        def write(output_path, content)
          path = normalized_path(output_path)
          FileUtils.mkdir_p(File.dirname(path)) unless File.dirname(path) == '.'
          File.binwrite(path, content.encode(Encoding::UTF_8))
          nil
        end

        def normalized_path(value)
          value = value.to_path if value.respond_to?(:to_path)
          return value if value.is_a?(String) && !value.empty?

          raise ArgumentError, 'output_path must be a non-empty path'
        end
        private_class_method :normalized_path
      end
    end
  end
end
