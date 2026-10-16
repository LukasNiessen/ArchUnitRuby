# ArchUnitRuby API Guide

This guide is the stable map of ArchUnitRuby's public fluent API. The
[class and method reference](class_list.html) is generated from the source, while this page explains
which entry point to choose and how the stages fit together.

All rule builders are immutable and lazy. Constructing a rule does not read the project; `check`,
`measure`, `snapshot`, and export methods are the terminals that perform work.

## Common rule shape

~~~ruby
rule = ArchUnit.project_files
               .in_folder('app/api/**')
               .should_not.depend_on_files
               .in_folder('app/database/**')

violations = rule.check
~~~

| Stage | Public vocabulary | Result |
| --- | --- | --- |
| Entry | `project_files`, `project_layers`, `project_slices`, `project_graph`, `metrics` | Immutable builder |
| Scope | `with_name`, `in_folder`, `in_path`, `in_file`, `for_classes_matching` | Narrower builder |
| Mood | `should`, `should_not` | Positive or negated predicate builder |
| Predicate | File, layer, slice, or metric policy | Checkable rule |
| Terminal | `check`, `measure`, `snapshot`, `to_*`, `export_as_*` | Data or an artifact |

String patterns are anchored globs. `*` stays inside one path segment, `**` crosses zero or more
segments, and `?` matches one non-separator character. A trailing folder glob such as
`app/api/**` includes the `app/api` folder itself and every descendant folder. Regular expressions
are accepted by all pattern selectors except the exact `in_file` selector.

Every pattern selector accepts `except:`. Pass a pattern, an array of patterns, or explicit selector
keys such as `{ in_folder: 'generated', with_name: '*_spec.rb' }`.

## File rules

Start with `ArchUnit.project_files(project_locator = nil)`; `ArchUnit.files` is its short alias.
Without a locator, ArchUnitRuby searches upward for a `Gemfile` or gemspec.

| Scope or predicate | Purpose |
| --- | --- |
| `with_name(pattern)` | Select or require a filename pattern |
| `in_folder(pattern)` | Select or require a project-relative directory |
| `in_path(pattern)` | Select or require a complete project-relative path |
| `in_file(path)` | Select one exact project-relative file |
| `have_no_cycles` | Reject cycles among selected project files |
| `depend_on_files` | Allow or reject dependencies matching target selectors |
| `depend_on_external_modules` | Allow or reject standard-library or gem imports |
| `adhere_to(callable, message)` | Evaluate a custom predicate over immutable `FileInfo` values |

~~~ruby
service_scope = ArchUnit.project_files.in_folder('app/services/**')

rules = [
  service_scope.should.have_name('*_service.rb'),
  service_scope.should_not.depend_on_files.in_folder('app/controllers/**'),
  service_scope.should_not.depend_on_external_modules.matching('net/http'),
  service_scope.should.adhere_to(
    ->(file) { file.lines_of_code < 300 },
    'services must stay below 300 non-blank lines'
  )
]
~~~

Positive dependency rules are allowlists: every selected dependency must match at least one target.
Negated dependency rules are blocklists: matching dependencies become violations.

## Layer rules

Use `ArchUnit.project_layers(project_locator = nil)` to name architectural layers and then declare
their allowed or forbidden relationships.

~~~ruby
rule = ArchUnit.project_layers
               .layer('api').defined_by('app/api/**/*.rb')
               .layer('services').defined_by_folder('app/services/**')
               .layer('database').defined_by('app/database/**/*.rb')
               .where_layer('api').may_only_depend_on_layers('services')
               .where_layer('services').may_only_depend_on_layers('database')
               .where_layer('database').may_only_depend_on_layers
~~~

`may_only_depend_on_layers` creates an allowlist. Calling it without targets seals the layer.
`may_not_depend_on_layers` creates a blocklist and requires at least one target. Dependencies inside
one layer are allowed; edges with an unassigned endpoint are ignored.

## Slices and diagrams

Use `ArchUnit.project_slices(project_locator = nil)` to capture one segment from project paths.
`(**)` is the glob capture; `defined_by_regex` uses the first regular-expression capture.

~~~ruby
slices = ArchUnit.project_slices.defined_by('lib/my_app/(**)/')

dependency_rule = slices.should_not.contain_dependency('api', 'database')
diagram_rule = slices.should
                     .ignoring_external_slices
                     .ignoring_orphan_slices
                     .adhere_to_diagram_in_file('docs/architecture.puml')

plantuml = slices.to_plantuml
slices.export_as_plantuml('reports/architecture.puml')
~~~

`adhere_to_diagram` accepts inline PlantUML. The supported subset includes components, directed
dependencies, comments, `@startuml`, and `@enduml`.

## Dependency graph reports

Use `ArchUnit.project_graph(project_locator = nil)` for queryable snapshots and reports.

~~~ruby
report = ArchUnit.project_graph
                 .include_external_dependencies
                 .focus_on('app/services/**', 2)
                 .collapse_to_folder_depth(2)
                 .titled('Service dependencies')

summary = report.summary
snapshot = report.snapshot
report.export_as_mermaid('reports/services.mmd')
report.export_as_html('reports/services.html')
~~~

Query modifiers are `focus_on(pattern, depth)`, `reachable_from(pattern)`, and
`dependents_of(pattern)`. Group nodes with `collapse_to_folder_depth` or
`collapse_by_pattern(pattern, replacement)`. Formats are DOT, Mermaid, D2, CSV, JSON, and
self-contained HTML; each provides both `to_<format>` and `export_as_<format>`.

## Metrics

Start with `ArchUnit.metrics(project_locator = nil)`. Select files with the standard file selectors
and classes with `for_classes_matching`.

~~~ruby
services = ArchUnit.metrics
                   .in_path('app/services/**/*.rb')
                   .for_classes_matching('*Service')

rules = [
  services.count.method_count.should_be_below_or_equal(20),
  services.lcom.lcom4.should_be(1),
  services.distance.instability.should_be_below(0.8)
]

measurements = services.count.method_count.measure
services.count.export_as_html('reports/service-counts')
~~~

Count metrics cover methods, fields, lines, statements, imports, classes, and top-level functions.
Cohesion provides LCOM96a, LCOM96b, LCOM1-5, and LCOM*. Distance metrics include abstractness,
instability, main-sequence distance, normalized distance, and coupling factor.

Thresholds use exactly `should_be_below`, `should_be_above`, `should_be`,
`should_be_below_or_equal`, `should_be_above_or_equal`, and `should_satisfy`. Use `custom_metric`
for a calculation over `ClassInfo`; zone guards are `not_in_zone_of_pain` and
`not_in_zone_of_uselessness`.

## Checking and test frameworks

Every architecture rule includes `ArchUnit::Checkable` and exposes `check(options = nil)`. It returns
an array of structured `Violation` values; an architecture disagreement is not an exception until
an assertion adapter translates it at the test boundary.

~~~ruby
violations = rule.check

expect(rule).to pass         # RSpec
assert_passes(rule)          # Minitest
ArchUnit.assert_passes(rule) # Framework-neutral
~~~

Use `ArchUnit.format_violations` or `ArchUnit::ResultFactory` when integrating with another test
framework or command-line interface.

## Check options and logging

`ArchUnit::CheckOptions` keeps optional execution behavior out of the fluent sentence:

~~~ruby
logging = ArchUnit::LoggingOptions.new(
  level: :debug,
  output_directory: 'tmp/archunit-logs'
)

options = ArchUnit::CheckOptions.new(
  allow_empty_tests: false,
  clear_cache: false,
  load_paths: ['components/billing/lib'],
  logging: logging
)

violations = rule.check(options)
~~~

Zero selected subjects produce `EmptyTestViolation` by default. Set `allow_empty_tests: true` only
when an empty scope is intentionally valid. Set `clear_cache: true` after modifying the analyzed
project during one process. `load_paths` adds project-contained source roots without evaluating
gemspecs or running application code.

## Errors and support

Invalid API input raises `ArchUnit::UserError` or `ArgumentError`; library or environment failures
raise `ArchUnit::TechnicalError`. Rule failures remain violation data.

See the [main guide](index.html) for installation and complete examples, [SUPPORT.md](https://github.com/LukasNiessen/ArchUnitRuby/blob/main/SUPPORT.md)
for help, and [SECURITY.md](https://github.com/LukasNiessen/ArchUnitRuby/blob/main/SECURITY.md) for
responsible vulnerability reporting.
