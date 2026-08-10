# frozen_string_literal: true

module ArchUnit
  module Metrics
    # Immutable Ruby source facts used by metric calculations.
    module Extraction
      # Shared constructor validation for the immutable extraction values.
      module ValueValidation
        private

        def immutable_string(value, attribute, normalize_path: false)
          valid = value.is_a?(String) && !value.empty?
          raise ArgumentError, "#{attribute} must be a non-empty String" unless valid

          value = value.tr('\\', '/') if normalize_path
          value.dup.freeze
        end

        def immutable_names(values, attribute)
          names = Array(values).map do |value|
            immutable_string(value, attribute)
          end
          names.uniq.sort.freeze
        end

        def immutable_values(values, type, attribute)
          result = Array(values).dup
          unless result.all?(type)
            type_name = type.name.split('::').last
            raise ArgumentError, "#{attribute} must contain only #{type_name} values"
          end

          result.freeze
        end

        def non_negative_integer(value, attribute)
          return value if value.is_a?(Integer) && value >= 0

          raise ArgumentError, "#{attribute} must be a non-negative Integer"
        end
      end
      private_constant :ValueValidation

      # One method and the instance fields it reads or writes.
      MethodInfo = Data.define(:name, :accessed_fields) do
        include ValueValidation

        def initialize(name:, accessed_fields: [])
          name = immutable_string(name, :name)
          accessed_fields = immutable_names(accessed_fields, :accessed_fields)
          super
        end
      end

      # One instance field and the methods that read or write it.
      FieldInfo = Data.define(:name, :accessed_by) do
        include ValueValidation

        def initialize(name:, accessed_by: [])
          name = immutable_string(name, :name)
          accessed_by = immutable_names(accessed_by, :accessed_by)
          super
        end
      end

      # Static information about one Ruby class declaration.
      # rubocop:disable Lint/DataDefineOverride -- `methods` is the established metric vocabulary.
      ClassInfo = Data.define(:name, :file_path, :methods, :fields) do
        include ValueValidation

        def initialize(name:, file_path:, methods: [], fields: [])
          name = immutable_string(name, :name)
          file_path = immutable_string(file_path, :file_path, normalize_path: true)
          methods = immutable_values(methods, MethodInfo, :methods)
          fields = immutable_values(fields, FieldInfo, :fields)
          super
        end

        def identifier
          "#{file_path}:#{name}"
        end
      end
      # rubocop:enable Lint/DataDefineOverride

      # Static counts and class declarations extracted from one Ruby source file.
      FileInfo = Data.define(
        :path,
        :lines_of_code,
        :statement_count,
        :import_count,
        :class_count,
        :function_count,
        :class_infos
      ) do
        include ValueValidation

        # rubocop:disable Metrics/ParameterLists -- The file has six independent count facts.
        def initialize(
          path:,
          lines_of_code:,
          statement_count:,
          import_count:,
          class_count:,
          function_count:,
          class_infos: []
        )
          path = immutable_string(path, :path, normalize_path: true)
          lines_of_code = non_negative_integer(lines_of_code, :lines_of_code)
          statement_count = non_negative_integer(statement_count, :statement_count)
          import_count = non_negative_integer(import_count, :import_count)
          class_count = non_negative_integer(class_count, :class_count)
          function_count = non_negative_integer(function_count, :function_count)
          class_infos = immutable_values(class_infos, ClassInfo, :class_infos)
          super
        end
        # rubocop:enable Metrics/ParameterLists

        def identifier
          path
        end
      end

      # Complete immutable metric input for one located Ruby project.
      ProjectInfo = Data.define(:project_root, :files) do
        include ValueValidation

        def initialize(project_root:, files: [])
          project_root = immutable_string(
            project_root, :project_root, normalize_path: true
          )
          files = immutable_values(files, FileInfo, :files)
          super
        end

        def classes
          files.flat_map(&:class_infos).freeze
        end
      end
    end
  end
end
