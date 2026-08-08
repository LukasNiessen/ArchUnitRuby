# frozen_string_literal: true

module ArchUnit
  # Language-neutral kernel types and operations.
  module Common
    FILTER_TARGETS = %i[filename path path_without_filename classname].freeze
    FILTER_MATCHING_MODES = %i[exact partial].freeze
    private_constant :FILTER_TARGETS, :FILTER_MATCHING_MODES

    # An immutable regular-expression filter with its matching target and exclusions.
    Filter = Data.define(:regexp, :target, :matching, :exclusions) do
      def initialize(regexp:, target:, matching: :partial, exclusions: [])
        regexp = immutable_regexp(regexp)
        validate_member(target, FILTER_TARGETS, :target)
        validate_member(matching, FILTER_MATCHING_MODES, :matching)
        exclusions = immutable_exclusions(exclusions)

        super
      end

      private

      def immutable_regexp(value)
        raise ArgumentError, 'regexp must be a Regexp' unless value.is_a?(Regexp)

        value.dup.freeze
      end

      def validate_member(value, allowed, attribute)
        return if allowed.include?(value)

        raise ArgumentError, "unknown #{attribute}: #{value.inspect}"
      end

      def immutable_exclusions(values)
        filters = Array(values).dup
        invalid_filters = filters.grep_v(self.class)
        unless invalid_filters.empty?
          raise ArgumentError, 'exclusions must contain only Filter values'
        end

        filters.freeze
      end
    end
  end
end
