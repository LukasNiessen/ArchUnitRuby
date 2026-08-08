# frozen_string_literal: true

module ArchUnit
  module Common
    module Extraction
      # The dependency forms the Ruby extractor records on graph edges.
      module ImportKind
        REQUIRE = :require
        REQUIRE_RELATIVE = :require_relative
        AUTOLOAD = :autoload
        LOAD = :load

        ALL = [REQUIRE, REQUIRE_RELATIVE, AUTOLOAD, LOAD].freeze

        def self.valid?(value)
          ALL.include?(value)
        end
      end
    end
  end
end
