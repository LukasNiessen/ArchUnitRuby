# Changelog

## 0.0.2 (unreleased)

- Fail closed on malformed included Ruby in dependency graphs and AST metrics, with structured
  source diagnostics and profile counters instead of silently treating incomplete analysis as clean.

- Add development-only locked dependency scanning with advisory refresh, fail-closed health checks,
  Windows path normalization, and retained CI reports.

- Avoid stack overflows in strongly-connected-component detection, elementary-cycle traversal,
  and blocked-vertex propagation on deep dependency graphs.
- Skip symlinked source entries and enforce canonical project boundaries for direct file metadata.
- Reuse source-entry file status instead of repeating separate directory and file probes.
- Validate version/changelog/lock consistency in CI and require prepared release metadata before
  RubyGems publication.

- Apply bounded project-root `.archignore` exclusions consistently to dependency graphs and metrics,
  with cache invalidation, cross-platform glob handling, and configuration safety checks.

- Add immutable `.because(...)` explanations to every executable rule and shared assertion output.

- Add opt-in debug inspection of project roots, graphs, and selected files on cold and cached checks.
- Log passing metric values without repeating custom calculations.
- Document verbosity, CI log artifacts, and existing colored violation reports.

- Add opt-in project constant-reference dependencies with lexical lookup and conservative ambiguity handling.
- Infer import paths from safely known local literal strings without evaluating application code.
- Preserve dependency source evidence in expanded mode through graph merging and JSON reporting,
  while keeping import-only edge values compatible with existing consumers.
- Support check options on metric measurements and add installed-gem extraction regression checks.
- Make trailing folder globs such as `app/api/**` include the named folder itself.
- Validate the README quickstart as a passing and failing end-to-end architecture test.
- Add a curated API guide, reliable Markdown rendering, responsive documentation navigation, and
  documentation quality checks.
- Add the ArchUnitRuby family logo, social preview, and repository community health files.
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
