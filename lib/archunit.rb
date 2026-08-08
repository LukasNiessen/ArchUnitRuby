# frozen_string_literal: true

require_relative 'archunit/version'
require_relative 'archunit/error/technical_error'
require_relative 'archunit/error/user_error'
require_relative 'archunit/common/pattern'
require_relative 'archunit/common/filter'
require_relative 'archunit/common/pattern_matching'
require_relative 'archunit/common/regex_factory'
require_relative 'archunit/common/assertion/violation'
require_relative 'archunit/common/assertion/empty_test_violation'
require_relative 'archunit/common/fluentapi/check_options'
require_relative 'archunit/common/fluentapi/checkable'
require_relative 'archunit/common/extraction/import_kind'
require_relative 'archunit/common/extraction/edge'
require_relative 'archunit/common/extraction/graph'
require_relative 'archunit/extraction/locate_project'
require_relative 'archunit/extraction/enumerate_source_files'

module ArchUnit
  Filter = Common::Filter
  PatternMatching = Common::PatternMatching
  RegexFactory = Common::RegexFactory
  Violation = Common::Assertion::Violation
  EmptyTestViolation = Common::Assertion::EmptyTestViolation
  CheckOptions = Common::FluentApi::CheckOptions
  Checkable = Common::FluentApi::Checkable
  ImportKind = Common::Extraction::ImportKind
  Edge = Common::Extraction::Edge
  Graph = Common::Extraction::Graph
end
