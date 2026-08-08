# frozen_string_literal: true

module ArchUnit
  module Common
    module Assertion
      # Marker base for data-only architecture rule failures.
      class Violation
        def initialize
          freeze
        end
      end
    end
  end
end
