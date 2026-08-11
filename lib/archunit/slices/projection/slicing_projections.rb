# frozen_string_literal: true

require_relative 'slice_projection'
require_relative '../../common/pattern_matching'
require_relative '../../common/regex_factory'

module ArchUnit
  module Slices
    # Projections from file dependencies into architectural slices.
    module Projection
      CAPTURE = '(**)'

      module_function

      def identity
        SliceProjection.new { |path| path }
      end

      def slice_by_pattern(pattern, except: nil)
        regexp = slice_pattern_regexp(pattern)
        slice_by_regex(regexp, except:)
      end

      def slice_by_regex(regexp, except: nil)
        regexp = immutable_regexp(regexp)
        selector = Common::RegexFactory.path_matcher('**', except:)
        SliceProjection.new do |path|
          next unless Common::PatternMatching.matches_pattern?(path, selector)

          match = regexp.match(path)
          match && non_empty_capture(match[1])
        end
      end

      def slice_by_file_suffix(labeling)
        labels = immutable_suffix_labels(labeling)
        SliceProjection.new do |path|
          filename = path.split('/').last
          extension = File.extname(filename)
          stem = extension.empty? ? filename : filename.delete_suffix(extension)
          labels.find { |suffix, _label| stem.end_with?(suffix) }&.last
        end
      end

      def slice_pattern_regexp(pattern)
        validate_slice_pattern(pattern)

        escaped = Regexp.escape(pattern.tr('\\', '/'))
        source = escaped.sub(Regexp.escape(CAPTURE), '([^/]+)')
                        .gsub('\\*\\*', '.*')
                        .gsub('\\*', '[^/]*')
        Regexp.new(source).freeze
      end
      private_class_method :slice_pattern_regexp

      def validate_slice_pattern(value)
        unless value.is_a?(String) && !value.empty?
          raise ArgumentError, 'pattern must be a non-empty String'
        end
        return if value.scan(CAPTURE).length == 1

        raise ArgumentError, "pattern must contain exactly one #{CAPTURE} slice capture"
      end
      private_class_method :validate_slice_pattern

      def immutable_regexp(value)
        return Regexp.new(value.source, value.options).freeze if value.is_a?(Regexp)

        raise ArgumentError, 'regexp must be a Regexp with a slice capture group'
      end
      private_class_method :immutable_regexp

      def non_empty_capture(value)
        value if value.is_a?(String) && !value.empty?
      end
      private_class_method :non_empty_capture

      def immutable_suffix_labels(value)
        unless value.is_a?(Hash) && !value.empty?
          raise ArgumentError, 'labeling must be a non-empty Hash of suffixes to slice names'
        end

        labels = value.map do |suffix, label|
          [non_empty_string(suffix, :suffix), non_empty_string(label, :slice_name)]
        end
        labels.sort_by { |suffix, _label| -suffix.length }.freeze
      end
      private_class_method :immutable_suffix_labels

      def non_empty_string(value, attribute)
        return value.dup.freeze if value.is_a?(String) && !value.empty?

        raise ArgumentError, "#{attribute} must be a non-empty String"
      end
      private_class_method :non_empty_string
    end
  end
end
