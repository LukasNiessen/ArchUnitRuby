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
require_relative 'archunit/common/projection/mapped_edge'
require_relative 'archunit/common/projection/projected_edge'
require_relative 'archunit/common/projection/projected_node'
require_relative 'archunit/common/projection/edge_projections'
require_relative 'archunit/common/projection/project_edges'
require_relative 'archunit/common/projection/project_to_nodes'
require_relative 'archunit/common/projection/project_cycles'
require_relative 'archunit/extraction/locate_project'
require_relative 'archunit/extraction/enumerate_source_files'
require_relative 'archunit/extraction/resolved_import'
require_relative 'archunit/extraction/resolve_import'
require_relative 'archunit/extraction/extract_imports'
require_relative 'archunit/extraction/extract_dependencies'
require_relative 'archunit/extraction/extract_graph'
require_relative 'archunit/files/fluentapi/files'
require_relative 'archunit/testing'

# Public ArchUnitRuby API and shared data types.
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
  MappedEdge = Common::Projection::MappedEdge
  ProjectedEdge = Common::Projection::ProjectedEdge
  ProjectedNode = Common::Projection::ProjectedNode
  CycleViolation = Files::Assertion::CycleViolation
  FilePatternViolation = Files::Assertion::FilePatternViolation
  FileDependencyViolation = Files::Assertion::FileDependencyViolation
  ExternalModuleDependencyViolation = Files::Assertion::ExternalModuleDependencyViolation
  FileInfo = Files::Extraction::FileInfo
  CustomFileViolation = Files::Assertion::CustomFileViolation
  TestViolation = Testing::TestViolation
  TestResult = Testing::TestResult
  ColorUtils = Testing::ColorUtils
  ViolationFactory = Testing::ViolationFactory
  ResultFactory = Testing::ResultFactory

  def self.clear_graph_cache
    Extraction.clear_graph_cache
  end
end
