# frozen_string_literal: true

require_relative 'slice_scope_builder'

# Public ArchUnitRuby entry points for slice architecture rules.
module ArchUnit
  module Slices
    # Sentence-like entry points and builders for slice architecture rules.
    module FluentApi
      module_function

      def project_slices(project_locator = nil)
        SliceScopeBuilder.new(project_locator:)
      end

      class << self
        alias slices project_slices
      end
    end
  end

  def self.project_slices(project_locator = nil)
    Slices::FluentApi.project_slices(project_locator)
  end

  class << self
    alias slices project_slices
  end
end
