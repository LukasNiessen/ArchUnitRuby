# frozen_string_literal: true

require_relative 'layered_architecture'

# Public ArchUnitRuby entry points for named layer policies.
module ArchUnit
  module Layers
    # Sentence-like entry points and builders for layer architecture rules.
    module FluentApi
      module_function

      def project_layers(project_locator = nil)
        LayeredArchitecture.new(project_locator:)
      end

      class << self
        alias layers project_layers
      end
    end
  end

  def self.project_layers(project_locator = nil)
    Layers::FluentApi.project_layers(project_locator)
  end

  class << self
    alias layers project_layers
  end
end
