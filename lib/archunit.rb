# frozen_string_literal: true

require_relative 'archunit/version'
require_relative 'archunit/common/pattern'
require_relative 'archunit/common/filter'
require_relative 'archunit/common/pattern_matching'
require_relative 'archunit/common/regex_factory'
require_relative 'archunit/common/extraction/import_kind'
require_relative 'archunit/common/extraction/edge'
require_relative 'archunit/common/extraction/graph'

module ArchUnit
  Filter = Common::Filter
  PatternMatching = Common::PatternMatching
  RegexFactory = Common::RegexFactory
  ImportKind = Common::Extraction::ImportKind
  Edge = Common::Extraction::Edge
  Graph = Common::Extraction::Graph
end
