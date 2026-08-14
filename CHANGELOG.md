# Changelog

## Unreleased

- Discover adjacent `lib` directories in multi-gemspec repositories without evaluating gemspecs.
- Support validated, project-local custom load paths through `CheckOptions`.
- Add cold/warm extraction profiling, a reproducible benchmark, and resolution caching.

## 0.0.1 - 2026-08-11

Initial executable prototype.

- Analyze Ruby dependencies expressed with `require`, `require_relative`, `autoload`, and `load`.
- Enforce file, layer, slice, PlantUML, and custom-predicate architecture rules.
- Measure count, cohesion, coupling, instability, abstractness, and main-sequence metrics.
- Export dependency graphs and metric reports in machine-readable and visual formats.
- Integrate with RSpec, Minitest, or framework-neutral assertions.
- Provide per-check logging, selector exclusions, generated API documentation, and Ruby 3.3+
  compatibility.
