# frozen_string_literal: true

require_relative 'filter'
require_relative 'pattern'

module ArchUnit
  module Common
    # The single construction point for user patterns and their matching targets.
    class RegexFactory
      TARGETED_EXCLUSIONS = {
        in_path: :path,
        in_folder: :path_without_filename,
        with_name: :filename,
        for_classes_matching: :classname
      }.freeze
      DEFAULT_EXCLUSION_TARGETS = {
        filename: %i[filename],
        path: %i[path filename],
        path_without_filename: %i[path path_without_filename filename],
        classname: %i[classname]
      }.freeze

      class << self
        def filename_matcher(pattern, except: nil)
          create_matcher(pattern, :filename, except:)
        end

        def folder_matcher(pattern, except: nil)
          create_matcher(pattern, :path_without_filename, except:)
        end

        def path_matcher(pattern, except: nil)
          create_matcher(pattern, :path, except:)
        end

        def classname_matcher(pattern, except: nil)
          create_matcher(pattern, :classname, except:)
        end

        def exact_file_matcher(file_path, except: nil)
          unless file_path.is_a?(String) && !file_path.empty?
            raise ArgumentError, 'file_path must be a non-empty String'
          end

          normalized_path = file_path.tr('\\', '/')
          regexp = Regexp.new("\\A#{Regexp.escape(normalized_path)}\\z")
          exclusions = create_exclusion_filters(:path, except)
          Filter.new(regexp:, target: :path, matching: :exact, exclusions:)
        end

        private

        def create_matcher(pattern, target, except:)
          exclusions = create_exclusion_filters(target, except)
          Filter.new(regexp: Pattern.compile(pattern), target:, exclusions:)
        end

        def create_exclusion_filters(parent_target, exclusion)
          return [] if exclusion.nil?
          return targeted_exclusion_filters(exclusion) if exclusion.is_a?(Hash)

          exclusion_patterns(exclusion).flat_map do |pattern|
            DEFAULT_EXCLUSION_TARGETS.fetch(parent_target).map do |target|
              simple_filter(pattern, target)
            end
          end
        end

        def targeted_exclusion_filters(exclusion)
          unknown = exclusion.keys - TARGETED_EXCLUSIONS.keys
          unless unknown.empty?
            raise ArgumentError, "unknown targeted exclusion: #{unknown.first.inspect}"
          end

          exclusion.flat_map do |name, patterns|
            exclusion_patterns(patterns).map do |pattern|
              simple_filter(pattern, TARGETED_EXCLUSIONS.fetch(name))
            end
          end
        end

        def exclusion_patterns(value)
          values = value.is_a?(Array) ? value : [value]
          values.each { |pattern| Pattern.compile(pattern) }
          values
        end

        def simple_filter(pattern, target)
          Filter.new(regexp: Pattern.compile(pattern), target:)
        end
      end

      private_class_method :new
    end
  end
end
