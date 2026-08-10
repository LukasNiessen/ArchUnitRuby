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
| Slice and metric rules | Planned |
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

## Example repository

The [ArchUnitRuby RAG test repository](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG)
is an executable layered retrieval-augmented-generation fixture. It contains realistic dependencies,
two intentional architecture violations, application tests, architecture extraction tests, and its
own cross-platform CI workflow.

The fixture proves the current prototype end to end: project discovery, source enumeration, import
resolution, graph assembly, internal/external classification, caching, executable file rules, and
direct formatting/assertion of its deliberate dependency and custom-predicate violations. It also
executes the native RSpec matcher, a complete named-layer policy, graph queries and collapsing, all
six renderers, and an exported self-contained HTML report over the RAG application.

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

Not implemented yet:

- the fluent slice and metric APIs;
- remaining architecture assertions over the projected graph;
- RubyGems publication and stable installation instructions;
- additional reporting, logging, and metrics.

Until those pieces land, treat the gem as an actively developed prototype rather than a stable
release.
