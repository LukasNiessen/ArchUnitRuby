# ArchUnitRuby

Architecture testing for Ruby. Part of **ArchUnitEverything** — one architecture-testing library per language.

> Early development. Nothing to install yet.

Siblings: [ArchUnitTS](https://github.com/LukasNiessen/ArchUnitTS) ·
[ArchUnitPython](https://github.com/LukasNiessen/ArchUnitPython)

[![CI](https://github.com/LukasNiessen/ArchUnitRuby/actions/workflows/ci.yml/badge.svg)](https://github.com/LukasNiessen/ArchUnitRuby/actions/workflows/ci.yml)
[![Ruby 3.3+](https://img.shields.io/badge/Ruby-3.3%2B-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/LukasNiessen/ArchUnitRuby.svg)](https://github.com/LukasNiessen/ArchUnitRuby)

ArchUnitRuby analyzes a Ruby project as a directed dependency graph. The finished library will let
teams express architecture rules as ordinary RSpec or Minitest tests, keeping dependency direction,
layers, cycles, naming conventions, diagrams, and metrics executable in CI.

## Current status

ArchUnitRuby is a working **executable prototype**, not a released end-user library yet. The full
source-to-graph path and the critical-path Files API run today.

| Capability | Status |
| --- | --- |
| Project discovery through a directory, `Gemfile`, or gemspec | Working |
| Ruby source enumeration with configurable exclusions | Working |
| Static `require`, `require_relative`, `autoload`, and `load` extraction | Working |
| Inline and next-line `# archunit: ignore` directives | Working |
| Internal and external dependency classification | Working |
| Self-edges and parallel-edge merging | Working |
| Immutable graph values and graph caching | Working |
| Immutable file selectors and `should` / `should_not` moods | Working |
| Cycle, filename, folder, and path file rules | Working |
| Internal-file and external-module dependency rules | Working |
| Custom `FileInfo` predicates and universal empty-test guard | Working |
| Violation formatting, result shaping, and `ArchUnit.assert_passes` | Working |
| Native RSpec `pass` matcher and Minitest `assert_passes` | Working |
| Immutable named-layer dependency policies | Working |
| Dependency graph snapshots, queries, and six report formats | Working |
| Slice dependency rules and PlantUML component diagrams | Working |
| Ruby metric extraction and count measurements | Working |
| LCOM96a/b, LCOM1-5, and LCOM* cohesion measurements | Working |
| Distance, coupling, and architectural zone checks | Working |
| Custom class metrics and `should_satisfy` | Working |
| Six metric threshold predicates | Working |
| Self-contained metrics HTML reports | Working |
| RubyGems installation | Not published yet |

The implementation has a growing RSpec suite and is tested on Ruby 3.3, 3.4, and 4.0 on Linux, plus
Ruby 4.0 on Windows.

## Try the prototype from source

Requirements: Ruby 3.3 or newer and Bundler.

```bash
git clone https://github.com/LukasNiessen/ArchUnitRuby.git
cd ArchUnitRuby
bundle install
bundle exec rake
```

The currently available API exposes the extracted graph directly:

```ruby
require 'archunit'

graph = ArchUnit::Extraction.extract_graph(
  '/path/to/project',
  exclude_patterns: ['vendor', 'tmp', '**/*_generated.rb']
)

graph.each do |edge|
  puts "#{edge.source} -> #{edge.target} (external: #{edge.external})"
end
```

File rules are immutable descriptions. Calling `check` extracts the graph and returns structured
violations; an architecture failure is data rather than an exception:

```ruby
cycle_violations = ArchUnit.project_files('/path/to/project')
                           .in_folder('lib/**')
                           .should.have_no_cycles
                           .check

naming_violations = ArchUnit.project_files('/path/to/project')
                            .in_folder('app/services')
                            .should.have_name('*_service.rb')
                            .check

dependency_violations = ArchUnit.project_files('/path/to/project')
                                .in_folder('app/api/**')
                                .should_not.depend_on_files
                                .in_folder('app/database/**')
                                .check

external_violations = ArchUnit.project_files('/path/to/project')
                              .in_folder('app/domain/**')
                              .should_not.depend_on_external_modules
                              .matching('faraday')
                              .check

custom_violations = ArchUnit.project_files('/path/to/project')
                            .in_folder('app/services')
                            .should.adhere_to(
                              ->(file) { file.lines_of_code < 300 },
                              'service files must stay below 300 non-blank lines'
                            )
                            .check
```

Use the framework-neutral assertion helper when a test should fail immediately, or format a result
without raising:

```ruby
rule = ArchUnit.project_files('/path/to/project')
               .in_folder('app/api/**')
               .should_not.depend_on_files
               .in_folder('app/database/**')

ArchUnit.assert_passes(rule)

result = ArchUnit::ResultFactory.from_violations(rule.check, color: false)
puts result.message unless result.passed?
```

RSpec users get a native matcher automatically when ArchUnitRuby is loaded by an RSpec process:

```ruby
RSpec.describe 'architecture' do
  it 'keeps the API away from the database' do
    rule = ArchUnit.files
                   .in_folder('app/api')
                   .should_not.depend_on_files
                   .in_folder('app/database')

    expect(rule).to pass
  end
end
```

Minitest users require Minitest before ArchUnitRuby and use its native assertion helper:

```ruby
require 'minitest/autorun'
require 'archunit'

class ArchitectureTest < Minitest::Test
  def test_api_does_not_reach_the_database
    rule = ArchUnit.files
                   .in_folder('app/api')
                   .should_not.depend_on_files
                   .in_folder('app/database')

    assert_passes(rule)
  end
end
```

Both integrations accept an optional `CheckOptions` value and translate failures into the test
framework's native failure type. Neither framework is a runtime dependency of the gem.

Graph extraction is cached because a real test suite evaluates many rules against the same project.
Force one fresh extraction with `CheckOptions`, or clear every cached graph globally:

```ruby
options = ArchUnit::CheckOptions.new(clear_cache: true)
graph = ArchUnit::Extraction.extract_graph('/path/to/project', options: options)

ArchUnit.clear_graph_cache
```

## How extraction works

ArchUnitRuby uses [Prism](https://github.com/ruby/prism), Ruby's official parser, and never executes
the analyzed source. It records dependencies whose targets can be read statically.

| Ruby form | Import kind |
| --- | --- |
| `require 'json'` | `:require` |
| `require_relative '../models/user'` | `:require_relative` |
| `autoload :User, 'models/user'` | `:autoload` |
| `load 'config/setup.rb'` | `:load` |

Literal imports are resolved using Ruby's feature resolution rules. Project files use normalized,
project-relative identifiers; standard-library and third-party dependencies retain the module name
written in source. Files Prism cannot parse are skipped without aborting the project scan.

Ruby can compute dependency names dynamically, so calls such as `require dependency_name` or
`require "plugins/#{name}"` cannot be resolved reliably without executing application code. They
are deliberately omitted rather than guessed.

Known compatibility imports can be suppressed inline or on the immediately preceding line. Add
module names to scope a directive instead of hiding every import on that line:

```ruby
require 'legacy/client' # archunit: ignore legacy/client

# archunit: ignore experimental/plugin
require 'experimental/plugin'
```

## Fluent file rules

Relational rules read as an English sentence from left to right. Object selectors on internal files
are chainable and combined with AND. Repeated external-module `matching` selectors use OR:

```ruby
rule = ArchUnit.project_files('/path/to/project')
         .in_folder('app/api/**')
         .should_not
         .depend_on_files
         .in_folder('app/database/**')

violations = rule.check
```

Rules are immutable values. Building one does no filesystem work; the terminal check performs
extraction and returns structured violations rather than raising for architecture failures. Use the
native RSpec matcher, Minitest helper, or `ArchUnit.assert_passes` to translate that result into a
test failure.

Custom predicates receive an immutable `FileInfo` with its project-relative `path`, filename without
extension, extension, directory, complete source text, and non-blank line count. A selector matching
zero files returns `EmptyTestViolation` from every terminal unless a check explicitly sets
`allow_empty_tests: true`.

## Named layer policies

Layers provide a compact policy over groups of files, avoiding a matrix of pairwise file rules:

```ruby
rule = ArchUnit.project_layers('/path/to/project')
               .layer('api').defined_by_folder('app/api')
               .layer('services').defined_by_folder('app/services')
               .layer('database').defined_by_folder('app/database')
               .where_layer('api').may_only_depend_on_layers('services')
               .where_layer('services').may_only_depend_on_layers('database')
               .where_layer('database').may_only_depend_on_layers

expect(rule).to pass
```

`defined_by` matches full project-relative paths; `defined_by_folder` matches their folders. Repeat
`layer(name)` to add another selector to the same layer. `may_only_depend_on_layers` is an allowlist,
and calling it with no targets seals the source layer. `may_not_depend_on_layers` is a blocklist and
requires at least one target. Intra-layer dependencies are always allowed, edges with an unassigned
endpoint are ignored, and blocklists take precedence over allowlists. Policy source layers matching
no files produce `EmptyTestViolation` unless empty tests are explicitly allowed.

## Slice policies and PlantUML

Slices group files into architectural components through one captured path segment or the first
capture of a regular expression. A forbidden dependency rule reads as a complete sentence:

```ruby
rule = ArchUnit.project_slices('/path/to/project')
               .defined_by('lib/my_app/(**)/')
               .should_not
               .contain_dependency('api', 'database')

expect(rule).to pass
```

`(**)` is the one slice capture; the remaining `*` and `**` characters keep their usual glob
meaning. `defined_by_regex` uses the first capture group instead. Slice projections are also public
for custom graph work through `ArchUnit::SliceProjections.slice_by_pattern`, `slice_by_regex`,
`slice_by_file_suffix`, and `identity`. They preserve all concrete file edges aggregated into each
slice dependency.

An architect can make a PlantUML component diagram executable directly or from a UTF-8 file:

```ruby
rule = ArchUnit.project_slices('/path/to/project')
               .defined_by('lib/my_app/(**)/')
               .should
               .ignoring_external_slices
               .adhere_to_diagram_in_file('docs/architecture.puml')

expect(rule).to pass
```

The supported line-based subset recognizes `component [Name]`, `[A] -> [B]`, `[A] --> [B]`,
comments, and `@startuml` / `@enduml`. By default, every actual dependency must be allowed by the
diagram. `ignoring_orphan_slices` ignores dependencies with an undeclared endpoint, while
`ignoring_external_slices` ignores dependencies to required gems or standard-library modules.
File-backed diagrams remain lazy: the file is read only when `check` executes.

The reverse direction generates a stable diagram from the real project, including isolated slices:

```ruby
slices = ArchUnit.project_slices('/path/to/project')
                 .defined_by('lib/my_app/(**)/')

puts slices.to_plantuml
slices.export_as_plantuml('docs/discovered-architecture.puml')
```

Like every other rule family, slice builders are immutable and a definition matching no project
files returns `EmptyTestViolation` unless explicitly allowed.

## Dependency graph reports

Graph reports separate selection from presentation. The fluent builder first creates one immutable
snapshot; DOT, Mermaid, D2, CSV, JSON, and HTML then render exactly those same nodes, edges, counts,
and import kinds:

```ruby
report = ArchUnit.project_graph('/path/to/project')
                 .include_external_dependencies
                 .focus_on('app/services/**', 2)
                 .collapse_to_folder_depth(2)
                 .titled('Service dependencies')

snapshot = report.snapshot
puts "#{snapshot.summary.node_count} nodes, #{snapshot.summary.edge_count} edges"

puts report.to_mermaid
report.export_as_html('reports/service-dependencies.html')
```

Queries can focus on a pattern to a bounded neighbour depth, retain everything reachable from a
pattern, or retain everything that depends on it. Nodes can be collapsed to a folder depth or by a
regular-expression replacement before parallel edges are aggregated. External and self
dependencies are opt-in. Every modifier returns a new builder, and `with_check_options` supplies
the same cache controls used by architecture rules.

Each format has `to_dot`, `to_mermaid`, `to_d2`, `to_csv`, `to_json`, or `to_html` for an in-memory
string and a corresponding `export_as_<format>(path)` method. Exports are UTF-8 and create missing
parent directories. The HTML report is a self-contained offline document with its own graph
summary, dependency table, and embedded portable-source representations; it makes no network
requests.

## Source metrics and cohesion

Metric scopes use the same immutable selectors as architecture rules. Calling `measure` performs
the source scan and returns immutable measurements with the extracted subject, metric name, numeric
value, and stable project-relative identifier:

```ruby
services = ArchUnit.metrics('/path/to/project')
                   .in_folder('app/services')
                   .for_classes_matching('*Service')

services.count.method_count.measure.each do |measurement|
  puts "#{measurement.identifier}: #{measurement.value} methods"
end

services.lcom.lcom4.measure.each do |measurement|
  puts "#{measurement.identifier}: #{measurement.value} cohesion components"
end

services.distance.instability.measure.each do |measurement|
  puts "#{measurement.identifier}: #{measurement.value} instability"
end

size_rule = services.count.method_count.should_be_below_or_equal(20)
cohesion_rule = services.lcom.lcom4.should_be(1)
distance_rule = services.distance.distance_from_main_sequence.should_be_below(0.5)

[size_rule, cohesion_rule, distance_rule].each { |rule| ArchUnit.assert_passes(rule) }

zone_rule = services.distance.not_in_zone_of_pain
ArchUnit.assert_passes(zone_rule)

focus_rule = services.custom_metric(
  'member count',
  'Service classes should remain focused',
  ->(class_info) { class_info.methods.length + class_info.fields.length }
).should_satisfy(->(value, class_info) { value < 20 && class_info.name.end_with?('Service') })

ArchUnit.assert_passes(focus_rule)

report_options = ArchUnit::MetricsExportOptions.new(
  title: 'Service Architecture Metrics', include_timestamp: false
)
services.count.export_as_html('reports/service-counts', report_options)
```

Count metrics cover methods and instance fields per class, plus lines of code, statements, imports,
classes, and top-level method definitions per file. Ruby has no interface construct, so
ArchUnitRuby deliberately does not invent an interface count. A "function" count means a `def`
written at Ruby's top level; methods inside modules and classes are not counted as functions.

Class extraction recognizes ordinary and singleton methods, nested class/module names,
`attr_reader`, `attr_writer`, `attr_accessor`, and instance-variable reads and writes. It derives a
symmetric method-to-field graph from those facts. The LCOM family is then calculated without
touching the filesystem: LCOM96a, LCOM96b, LCOM1, LCOM2, LCOM3, LCOM4 connected components,
LCOM5, and LCOM*. Lower normalized values indicate stronger cohesion; LCOM4 reports the number of
disconnected method groups, where one connected component is cohesive.

Distance metrics enrich each file with distinct internal incoming and outgoing dependencies from
the real project graph. Abstractness recognizes Ruby mixin/contract modules with instance behavior
and classes whose abstract methods use the conventional `raise NotImplementedError` pattern;
namespace-only modules are excluded. The available values are abstractness, instability, distance
from the main sequence, coupling factor, and a source-size-normalized distance. Zone guards use the
conventional low/low and high/high abstractness-instability corners and return structured
`MetricZoneViolation` values.

`custom_metric(name, description, fn)` is the class-level escape hatch. Its calculation receives
the complete immutable `ClassInfo`; `measure` returns its values, while `should_satisfy` receives
both `(value, class_info)` and produces structured violations.

Every metric selection exposes exactly six predicates: `should_be_below`, `should_be_above`,
`should_be`, `should_be_below_or_equal`, `should_be_above_or_equal`, and `should_satisfy`. Numeric
boundaries are exact: a value equal to the argument fails the strict `below` and `above` forms but
passes the corresponding inclusive form. `should_satisfy` receives `(value, subject)`, where the
subject is the complete immutable `ClassInfo`, `MetricFileInfo`, or `DistanceInfo`. Empty selections
produce `EmptyTestViolation` unless `allow_empty_tests` is enabled, just like every other rule.

Count, LCOM, and distance builders can export all their scoped measurements as offline HTML with
`export_as_html(path, options)`. Missing directories and a missing `.html` extension are added
automatically. `MetricsExporter.export_as_html(data, options)` renders an arbitrary metric map and
returns the HTML string; `MetricsExportOptions` controls the title, UTC timestamp, custom CSS, and
optional output path. Titles, labels, and values are HTML-escaped, while reports contain no external
assets or network dependencies.

## Example repository

The [ArchUnitRuby RAG test repository](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG)
is an executable layered retrieval-augmented-generation fixture. It contains realistic dependencies,
two intentional architecture violations, application tests, architecture extraction tests, and its
own cross-platform CI workflow.

The fixture proves the current prototype end to end: project discovery, source enumeration, import
resolution, graph assembly, internal/external classification, caching, executable file rules, and
direct formatting/assertion of its deliberate dependency and custom-predicate violations. It also
executes the native RSpec matcher, a complete named-layer policy, graph queries and collapsing, all
six renderers, an exported self-contained HTML report, forbidden slice dependencies, and the
fixture's executable PlantUML architecture contract over the RAG application. Metric integration
tests extract real RAG service methods and fields, verify count measurements, and calculate all
eight supported LCOM variants over that source. They also validate real dependency-derived distance
values, a zone guard, and a custom class metric end to end.

## Download tracking

Ruby packages are distributed through RubyGems rather than PyPI. The `archunit` gem name is not
published yet, so there are no meaningful package-download statistics today. After the first release:

- [RubyGems](https://rubygems.org/gems/archunit) will report total and per-version downloads.
- [ClickGems](https://clickgems.clickhouse.com/dashboard/archunit) will provide PePy-style download
  charts over time, including version, Ruby version, system, and country breakdowns.
- A RubyGems total-download badge can be enabled with
  `https://img.shields.io/gem/dt/archunit`.

Counts begin with the first RubyGems publication; GitHub clones are separate and are visible only to
repository maintainers through GitHub traffic insights.

## Development

```bash
bundle exec rspec       # specifications
bundle exec rubocop     # style and static checks
bundle exec rake        # both
gem build archunit.gemspec
```

CI runs compatibility tests on Ruby 3.3, 3.4, and 4.0 across Ubuntu and Windows. A single Ruby 4.0
Ubuntu quality job enforces randomized specs, 98% line and 90% branch coverage, RuboCop, gem build,
and installation from the built artifact. A separate job runs the public RAG fixture against the
exact revision under test. Weekly Dependabot checks cover Bundler and GitHub Actions dependencies.
There is no automatic release or documentation deployment yet.

The project follows the conventions in [`AGENTS.md`](AGENTS.md); Ruby idioms win where a sibling
language's design does not fit naturally.

## Roadmap and limitations

The build backlog lives in [GitHub Issues](https://github.com/LukasNiessen/ArchUnitRuby/issues).
Extraction is complete through issue #12. Projection is complete through issue #15, including
standard edge mappers, evidence-preserving relabeling, node views, and Tarjan/Johnson cycle
detection. The critical-path Files API is complete through issue #23: immutable selectors and moods,
cycle/name/location predicates, internal/external dependency policy, custom `FileInfo` predicates,
and the universal empty-test guard.

Testing support is complete through issue #26: one violation factory owns every message, the result
factory returns an immutable pass flag and message, ANSI colour is optional and terminal-aware,
RSpec gets `expect(rule).to pass`, Minitest gets `assert_passes(rule)`, and
`ArchUnit.assert_passes` remains the framework-neutral fallback. Issue #27 adds immutable named
layers with allowlist, sealed-layer, and blocklist dependency policies. Issues #28 and #29 add the
shared dependency-graph snapshot, immutable queries and collapsing, and DOT, Mermaid, D2, CSV, JSON,
and self-contained HTML rendering.

Issues #30 and #31 add captured-path and regex slice projections, forbidden slice dependencies,
PlantUML component-diagram validation, orphan/external modifiers, and reverse diagram generation.

Issues #32 and #33 add immutable Ruby class/file metric extraction, seven count metrics, scoped
measurement builders, and the full requested LCOM cohesion family. Ruby's missing interface
concept is omitted explicitly rather than approximated with modules.

Issues #34 and #35 add dependency-derived abstractness, instability, main-sequence distance,
coupling, normalized distance, executable pain/uselessness zone guards, and custom class metrics
with their explicit `should_satisfy(value, class_info)` escape hatch.

Issues #36 and #37 add the exact shared threshold vocabulary, structured threshold/predicate
violations, and self-contained HTML reporting for arbitrary metric maps and scoped metric families.

Not implemented yet:

- remaining architecture assertions over the projected graph;
- RubyGems publication and stable installation instructions;
- additional reporting, logging, and metrics.

Until those pieces land, treat the gem as an actively developed prototype rather than a stable
release.
