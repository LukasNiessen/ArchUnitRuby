# frozen_string_literal: true

require_relative '../filter'
require_relative 'violation'

module ArchUnit
  module Common
    module Assertion
      # Data describing a rule whose selectors matched no candidates.
      class EmptyTestViolation < Violation
        attr_reader :filters, :is_negated

        def initialize(filters:, is_negated: false)
          @filters = immutable_filters(filters)
          @is_negated = boolean(is_negated, :is_negated)
          super()
        end

        def negated?
          is_negated
        end

        def ==(other)
          other.is_a?(self.class) && filters == other.filters && is_negated == other.is_negated
        end
        alias eql? ==

        def hash
          [self.class, filters, is_negated].hash
        end

        private

        def immutable_filters(values)
          unless values.is_a?(Array) && values.all?(Filter)
            raise ArgumentError, 'filters must be an Array of Filter values'
          end

          values.dup.freeze
        end

        def boolean(value, attribute)
          return value if [true, false].include?(value)

          raise ArgumentError, "#{attribute} must be true or false"
        end
      end
    end
  end
end
