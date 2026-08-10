# frozen_string_literal: true

module ArchUnit
  module GraphReporting
    module Projection
      # Collapse nodes by applying a regular-expression replacement.
      PatternCollapse = Data.define(:regexp, :replacement) do
        def initialize(regexp:, replacement: '\\1')
          raise ArgumentError, 'regexp must be a Regexp' unless regexp.is_a?(Regexp)
          raise ArgumentError, 'replacement must be a String' unless replacement.is_a?(String)

          super(regexp: regexp.dup.freeze, replacement: replacement.dup.freeze)
        end

        def self.from(pattern, replacement = '\\1')
          regexp = pattern.is_a?(String) ? Regexp.new(pattern) : pattern
          new(regexp:, replacement:)
        rescue RegexpError => e
          raise ArgumentError, "invalid collapse pattern: #{e.message}"
        end
      end
    end
  end
end
