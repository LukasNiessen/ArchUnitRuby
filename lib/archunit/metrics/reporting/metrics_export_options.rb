# frozen_string_literal: true

module ArchUnit
  module Metrics
    # Self-contained metrics report rendering and export.
    module Reporting
      # Immutable options for one metrics HTML report.
      MetricsExportOptions = Data.define(
        :output_path, :title, :include_timestamp, :custom_css
      ) do
        def self.resolve(value)
          return new if value.nil?
          return value if value.is_a?(self)

          raise ArgumentError, 'options must be a MetricsExportOptions value or nil'
        end

        def initialize(
          output_path: nil,
          title: 'ArchUnitRuby Metrics Report',
          include_timestamp: true,
          custom_css: nil
        )
          output_path = optional_path(output_path)
          title = immutable_string(title, :title)
          unless [true, false].include?(include_timestamp)
            raise ArgumentError, 'include_timestamp must be true or false'
          end

          custom_css = optional_string(custom_css, :custom_css)
          super
        end

        private

        def optional_path(value)
          return if value.nil?

          value = value.to_path if value.respond_to?(:to_path)
          immutable_string(value, :output_path)
        end

        def optional_string(value, attribute)
          return if value.nil?

          immutable_string(value, attribute)
        end

        def immutable_string(value, attribute)
          return value.dup.freeze if value.is_a?(String) && !value.empty?

          raise ArgumentError, "#{attribute} must be a non-empty String"
        end
      end
    end
  end
end
