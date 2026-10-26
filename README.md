# ArchUnitRuby - Architecture Testing

<p align="center" name="top">
  <img src="assets/logo-rounded.png" width="180" alt="ArchUnitRuby logo">
</p>

<p align="center">
  <a href="LICENSE"><img alt="License: MIT" src="https://img.shields.io/badge/License-MIT-yellow.svg"></a>
  <a href="https://github.com/LukasNiessen/ArchUnitRuby/actions/workflows/ci.yml"><img alt="Build & tests" src="https://img.shields.io/github/actions/workflow/status/LukasNiessen/ArchUnitRuby/ci.yml?branch=main&amp;label=build%20%26%20tests"></a>
  <a href="https://github.com/LukasNiessen/ArchUnitRuby"><img alt="GitHub stars" src="https://img.shields.io/github/stars/LukasNiessen/ArchUnitRuby.svg"></a><br>
  <a href="https://clickgems.clickhouse.com/dashboard/archunit"><img alt="Gem downloads" src="https://img.shields.io/gem/dt/archunit.svg"></a>
  <a href="https://www.ruby-lang.org/"><img alt="Ruby 3.3+" src="https://img.shields.io/badge/Ruby-3.3%2B-CC342D?logo=ruby&amp;logoColor=white"></a>
</p>

Enforce architecture rules in Ruby projects. Check dependency directions, detect circular
dependencies, enforce naming and location conventions, measure code quality, and generate
architecture reports as ordinary Ruby tests.

_Inspired by the amazing ArchUnit library, but not affiliated with ArchUnit._

[Setup](#-setup) · [Use Cases](#-use-cases) · [Features](#-features) · [API Guide](https://lukasniessen.github.io/ArchUnitRuby/file.API.html) · [Documentation](https://lukasniessen.github.io/ArchUnitRuby/) · [Contributing](CONTRIBUTING.md)

ArchUnitRuby turns a Ruby codebase into a dependency graph and lets you test that graph with rules
that read like English:

~~~ ruby
ArchUnit.project_files
        .in_folder('app/api/**')
        .should_not.depend_on_files
        .in_folder('app/database/**')
~~~

It is a working executable prototype with file, layer, slice, graph-reporting, and metric APIs. It
is tested on Ruby 3.3, 3.4, and 4.0 on Linux and Ruby 4.0 on Windows. Install the latest release as
[`archunit`](https://rubygems.org/gems/archunit) on RubyGems.

ArchUnitRuby follows the shared ArchUnitEverything architecture and fluent-API standard used by
its siblings [ArchUnitTS](https://github.com/LukasNiessen/ArchUnitTS) and
[ArchUnitPython](https://github.com/LukasNiessen/ArchUnitPython), adapted where Ruby idioms differ.

The [documentation site](https://lukasniessen.github.io/ArchUnitRuby/) combines this guide, a
curated [API guide](https://lukasniessen.github.io/ArchUnitRuby/file.API.html), and a searchable,
source-generated reference. The same site is rebuilt and link-validated in CI before deployment
from `main`, so the published reference follows the repository.

## ⚡ 5 min Quickstart

### Installation

ArchUnitRuby requires Ruby 3.3 or newer. Add it to your test dependencies:

~~~ ruby
# Gemfile
group :test do
  gem 'archunit', '~> 0.0.1'
end
~~~

Then install it:

~~~ bash
bundle install
~~~

Or install it directly with `gem install archunit`.

[ClickGems download analytics](https://clickgems.clickhouse.com/dashboard/archunit) show trends by
date, gem version, Ruby version, system, and country. Download totals count package fetches rather
than unique users, so repeated installs and automated clients may contribute to the total. The
[RubyGems API](https://rubygems.org/api/v1/gems/archunit.json) provides the
current raw count and ClickGems provides the historical breakdown.

RSpec and Minitest integrations are optional; ArchUnitRuby does not install either test framework
for you.

### Add tests

Create `spec/architecture_spec.rb`:

~~~ ruby
require 'archunit'

RSpec.describe 'architecture' do
  it 'keeps the API away from the database' do
    rule = ArchUnit.project_files.in_folder('app/api/**')
                   .should_not.depend_on_files.in_folder('app/database/**')

    expect(rule).to pass
  end
end
~~~

Run it like any other specification:

~~~ bash
bundle exec rspec spec/architecture_spec.rb
~~~

### CI Integration

Architecture specifications run with the rest of the test suite, so no dedicated CI integration
is required:

~~~ yaml
# GitHub Actions
- name: Run architecture tests
  run: bundle exec rspec spec/architecture_spec.rb
~~~

## 🚐 Setup

### Explain why a rule exists

Append `.because(...)` to a completed file, layer, slice, or metric rule:

~~~ ruby
rule = ArchUnit.project_files.in_folder('app/api/**')
               .should_not.depend_on_files.in_folder('app/database/**')
               .because('Keep persistence out of the API')

expect(rule).to pass
~~~

The explanation appears once in a failed RSpec, Minitest, or `ArchUnit.assert_passes` assertion.
It is available as `rule.rationale`. Calling `.because(...)` returns a distinct frozen rule;
the original rule and direct `check` results are unchanged. Reasons must be non-blank strings.
Add the explanation after all selectors and modifiers.

### Project Location

The project locator is optional. With no argument, ArchUnitRuby searches from the current directory
for a `Gemfile` or gemspec. Pass a directory or either marker file when analyzing another project:

~~~ ruby
ArchUnit.project_files('/workspace/my_app')
ArchUnit.project_files('/workspace/my_app/Gemfile')
~~~

Source discovery skips symlinked files and directories, including project-local aliases. This
avoids duplicate file identities and unintentionally parsing linked source outside the project.
Direct file-information extraction also checks the canonical source path against the project root.

### Project-wide exclusions

Add a `.archignore` at the detected project root to keep generated or intentionally out-of-scope
Ruby files out of dependency graphs and file-based metrics:

~~~ text
# Architecture exclusions (not a full gitignore parser)
/db/migrate/
generated/
**/*_generated.rb
~~~

Blank lines and full-line `#` comments are ignored. Bare names match at any directory depth;
patterns containing `/` are project-relative, and a leading `/` anchors a pattern to the root.
A trailing `/` matches directories and their descendants, not similarly named files. Windows
separators are normalized. Only the root file is read; nested `.archignore` files are not inherited.

These patterns combine with the built-in exclusions or explicit `exclude_patterns:`; `[]` disables
the defaults, not `.archignore`. Effective pattern changes automatically select a fresh cached graph.
Source-code edits still require `clear_cache: true` in a long-lived process. The file is limited to
1 MiB, must be a regular non-symlink file, and is decoded as UTF-8 with invalid bytes replaced.
Negation (`!pattern`), NUL characters, and a bare `/` are rejected with `ArchUnit::UserError`.
No configuration or application code is executed.

### Fluent Grammar

Every rule is built left to right from the same small grammar:

| Stage | Purpose | Examples |
| --- | --- | --- |
| Entry | Choose the architectural vocabulary | `project_files`, `project_layers`, `project_slices`, `project_graph`, `metrics` |
| Scope | Select subjects; repeated scopes use AND | `in_folder`, `in_path`, `with_name`, `for_classes_matching` |
| Mood | Choose the expected direction | `should`, `should_not` |
| Predicate | State the policy | `have_no_cycles`, `depend_on_files`, `adhere_to_diagram` |
| Object | Select the target of a relational rule | `in_folder`, `matching`, a layer or slice name |
| Terminal | Execute or render | `check`, `to_json`, `export_as_html`, `measure` |

Building a rule is lazy and does not scan the filesystem. `check`, `measure`, snapshot/report
terminals, and export terminals perform the work. Builders are immutable, so a scope can be reused:

~~~ ruby
services = ArchUnit.project_files.in_folder('app/services/**')

cycle_rule = services.should.have_no_cycles
database_rule = services.should_not.depend_on_files.in_folder('app/database/**')
~~~

String patterns are anchored globs. `*` stays inside one path segment, `**` crosses directories,
and `?` matches one non-separator character. Most selectors also accept regular expressions;
`defined_by_regex` is the explicit regex form for slices, while `in_file` takes one exact path.
Paths are project-relative and normalized to `/` separators.

A scope matching zero files returns `EmptyTestViolation`; it does not silently pass. Opt out only
when an empty result is genuinely valid:

~~~ ruby
rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))
~~~

## 🐣 Features

### File Rules

File rules cover cycles, naming, location, internal dependencies, external modules, and custom
source predicates:

~~~ ruby
rules = [
  ArchUnit.project_files.in_path('lib/**/*.rb').should.have_no_cycles,
  ArchUnit.project_files.in_folder('app/services/**')
          .should.have_name('*_service.rb'),
  ArchUnit.project_files.in_folder('app/domain/**')
          .should_not.depend_on_external_modules.matching('faraday')
]

rules.each { |rule| ArchUnit.assert_passes(rule) }
~~~

A custom predicate receives an immutable `FileInfo` with `path`, `name`, `extension`, `directory`,
complete `content`, and non-blank `lines_of_code`:

~~~ ruby
rule = ArchUnit.project_files.in_folder('app/services/**')
               .should.adhere_to(
                 ->(file) { file.lines_of_code < 300 },
                 'services must stay below 300 non-blank lines'
               )
~~~

### Layer Dependencies

Named layers express an allowlist or blocklist over groups of files:

~~~ ruby
rule = ArchUnit.project_layers
               .layer('api').defined_by('app/api/**/*.rb')
               .layer('services').defined_by('app/services/**/*.rb')
               .layer('database').defined_by('app/database/**/*.rb')
               .where_layer('api').may_only_depend_on_layers('services')
               .where_layer('services').may_only_depend_on_layers('database')
               .where_layer('database').may_only_depend_on_layers

expect(rule).to pass
~~~

Dependencies within one layer are always allowed. Edges with an unassigned endpoint are ignored.
Calling `may_only_depend_on_layers` without targets seals a layer; `may_not_depend_on_layers`
requires at least one forbidden target.

### Architecture Slices and PlantUML

Slices group files by one captured path segment and preserve every concrete dependency as evidence:

~~~ ruby
slices = ArchUnit.project_slices.defined_by('lib/my_app/(**)/')
rule = slices.should_not.contain_dependency('api', 'database')

expect(rule).to pass
~~~

`(**)` is the slice capture. `defined_by_regex` uses the first regular-expression capture instead.

A checked-in PlantUML component diagram can also be the architecture contract:

~~~ ruby
rule = slices.should
             .ignoring_external_slices
             .adhere_to_diagram_in_file('docs/architecture.puml')

expect(rule).to pass
~~~

The supported subset recognizes components, directed dependencies, comments, and `@startuml` /
`@enduml`. Use `to_plantuml` or `export_as_plantuml(path)` to generate a diagram from the real graph.

### Dependency Graph Reports

Graph reporting builds one immutable snapshot and renders it consistently as DOT, Mermaid, D2, CSV,
JSON, or self-contained HTML:

~~~ ruby
report = ArchUnit.project_graph
                 .include_external_dependencies
                 .focus_on('app/services/**', 2)
                 .collapse_to_folder_depth(2)
                 .titled('Service dependencies')

puts report.summary.node_count
report.export_as_html('reports/services.html')
~~~

Queries include `focus_on`, `reachable_from`, and `dependents_of`. Collapse by folder depth or a
regular-expression replacement. Every format has an in-memory `to_<format>` and an
`export_as_<format>(path)` terminal.

### Code Metrics

Metric scopes select files and Ruby classes before measurement or assertion:

~~~ ruby
services = ArchUnit.metrics
                   .in_path('app/services/**/*.rb')
                   .for_classes_matching('*Service')

size_rule = services.count.method_count.should_be_below_or_equal(20)
cohesion_rule = services.lcom.lcom4.should_be(1)
distance_rule = services.distance.instability.should_be_below(0.8)

[size_rule, cohesion_rule, distance_rule].each { |rule| ArchUnit.assert_passes(rule) }
~~~

Count metrics cover class methods and fields plus file lines, statements, imports, classes, and
top-level functions. Cohesion includes LCOM96a, LCOM96b, LCOM1-5, and LCOM*. Dependency-derived
metrics include abstractness, instability, main-sequence distance, coupling factor, and normalized
distance. Zone guards detect the conventional zones of pain and uselessness.

Use `measure` for immutable numeric results, `custom_metric` for a calculation over `ClassInfo`, and
`export_as_html` for an offline metrics report:

~~~ ruby
services.count.export_as_html('reports/service-counts')
~~~

The threshold vocabulary is intentionally limited to `should_be_below`, `should_be_above`,
`should_be`, `should_be_below_or_equal`, `should_be_above_or_equal`, and `should_satisfy`.

### Pattern Exclusions

Every selector accepts `except:` in the same call. A plain pattern or array uses the parent
selector's context, including filenames for path and folder selectors:

~~~ ruby
scope = ArchUnit.project_files.in_path(
  'app/**/*.rb',
  except: ['app/generated/**', 'schema.rb']
)
~~~

Use explicit targets when needed. Supported keys are `in_path`, `in_folder`, `with_name`, and
`for_classes_matching`:

~~~ ruby
scope = ArchUnit.metrics.in_path(
  'app/**/*.rb',
  except: { in_folder: 'app/generated', with_name: '*_spec.rb' }
)
~~~

## 🐹 Use Cases

### Results and Test Frameworks

`check` returns an array of structured violations. Architecture disagreement is data, not an
exception:

~~~ ruby
violations = rule.check
violations.each { |violation| puts violation.class }
~~~

Translate that result into a test failure at the boundary that suits your suite:

~~~ ruby
expect(rule).to pass              # RSpec
assert_passes(rule)               # Minitest test case
ArchUnit.assert_passes(rule)      # Framework-neutral
~~~

`ArchUnit.format_violations` and `ResultFactory` provide stable human-readable output. All
violations retain the concrete dependency, file, layer, slice, or metric evidence that caused them.

## 📝 Debug Logging & Configuration

Logging is off by default and belongs to one check; there is no process-global configuration:

~~~ ruby
logging = ArchUnit::LoggingOptions.new(
  level: :debug,
  output_directory: 'tmp/archunit-logs',
  append: false
)

violations = rule.check(ArchUnit::CheckOptions.new(logging: logging))
~~~

Levels are `debug`, `info`, `warn`, and `error`. The fixed events cover check start/end, progress,
violations, and metric evidence. `io:` defaults to `$stderr`, accepts any writable stream, and may be
`nil`. File output creates missing directories and writes timestamped `archunit-*.log` files.

At `:debug`, inspection includes the project root, each discovered file, every dependency with
its import kind and external flag, selected files, and all metric calculations (including passing
values). It observes the same graph on both cold and cached checks. Custom metrics run once.
Check options and returned violations retain their existing behavior.

| Level | Included output |
| --- | --- |
| `:debug` | Graph inspection, selections, metric values, and everything below |
| `:info` | Check lifecycle and progress, violations, technical errors |
| `:warn` | Violations and technical errors |
| `:error` | Technical errors |

Example debug lines (timestamp prefixes omitted):

~~~ text
[DEBUG] inspect: discovered file: "lib/service.rb"
[DEBUG] inspect: dependency: "lib/service.rb" -> "json" (external=true, kinds=[:require])
[DEBUG] inspect: selected file: "lib/service.rb"
[DEBUG] log metric: method_count=3 [lib/service.rb:Service]
~~~

For file-only CI artifacts, use `io: nil` with `output_directory:` and archive that directory.
Logging sink errors still propagate. Debug details are produced lazily; checks with logging
disabled create no output or log files.

### Readable, colored failure reports

The same formatted, numbered reports work with RSpec, Minitest, or standalone checks:

~~~ ruby
puts ArchUnit.format_violations(violations)               # Detect terminal support
puts ArchUnit.format_violations(violations, color: true)  # Force ANSI colors
puts ArchUnit.format_violations(violations, color: false) # Plain CI/file output
~~~

Failure headings are bold red, violation headings yellow, and successful results green. Reports
include dependency, file, or metric evidence. Automatic color detection respects `NO_COLOR`,
`TERM=dumb`, and non-terminal output. Log files remain plain text for searching and CI artifacts.

## 🕵️ Technical Deep Dive

### What ArchUnitRuby Extracts

ArchUnitRuby uses Prism and statically recognizes:

| Ruby source form | Import kind |
| --- | --- |
| `require 'json'` | `:require` |
| `require_relative '../models/order'` | `:require_relative` |
| `autoload :Order, 'models/order'` | `:autoload` |
| `load 'config/setup.rb'` | `:load` |

Project dependencies use normalized, project-relative paths. Standard-library and gem dependencies
retain the module name written in source. Inline or immediately preceding ignore directives can
suppress known compatibility imports:

~~~ ruby
require 'legacy/client' # archunit: ignore legacy/client

# archunit: ignore experimental/plugin
require 'experimental/plugin'
~~~

Preceding local assignments to literal strings are also recognized for all four import forms:

~~~ ruby
path = '../retrieval/store'
require_relative path
~~~

Inference follows assignment order within straight-line lexical scopes. Reassignment replaces the
value; aliases, mutation, unknown calls receiving the value, reflection, and unsupported control
flow invalidate it. Values are not carried across branches, loops, exception handlers, or captured
blocks. Once a closure or reflective binding can access an enclosing scope, local inference remains
disabled for that scope. Independent literal assignments inside a method or block can still resolve. Runtime values
such as `ENV.fetch('PLUGIN_PATH')`, interpolation, and method results remain unresolved. No source,
Gemfile, gemspec, initializer, or `const_missing` hook is executed.

### Constant References (Opt-in)

For autoloaded applications, enable dependencies from known project constants alongside imports:

~~~ ruby
options = ArchUnit::CheckOptions.new(dependency_analysis: :imports_and_constants)

# Detects Retrieval::Store.new even without require_relative.
rule = ArchUnit.project_files
               .in_path('app/api/**')
               .should_not.depend_on_files.in_path('app/retrieval/**')
violations = rule.check(options)

report = ArchUnit.project_graph.with_check_options(options)
puts report.to_json
puts ArchUnit.project_slices.defined_by('app/(**)/').to_plantuml(options)
values = ArchUnit.metrics.distance.instability.measure(options)
~~~

The default remains `dependency_analysis: :imports`. Expanded mode indexes declarations from the
same included source files, then resolves references to definition files. Files remain graph nodes.
It supports lexical nesting, compact namespaces, root-qualified names, and explicit superclass,
`include`, `prepend`, and `extend` references. Nested `module A; module B` includes `A` in lexical
lookup; top-level `module A::B` does not. A nearer namespace shadows a root namespace even when its
requested child is missing.

Ordinary `=` and conditional `||=` constant declarations are indexed, including qualified and
root-qualified forms. A conditional declaration records a possible definition file, not proof that
the assignment executes or its resulting value. Multiple candidate files stay ambiguous. Other
compound writes (`&&=`, operators) and multiple-assignment declarations are not inferred as new
definition owners; unsupported targets remain unresolved rather than inventing ownership.

References with multiple definition files (reopened classes/modules), missing definitions, and
dynamic definitions are omitted, never assigned to an arbitrary file. `Alias = Original` defines
`Alias` in its own file and records the reference to `Original`; lookup through aliases such as
`Alias::Child` is not followed. Inherited constant members and singleton-class lexical lookup are
not modeled. Unqualified root fallback is conservatively suppressed in scopes with an explicit
superclass, mixins, or dynamic constant operations. Use explicit `::Namespace::Constant` references
or import rules where those limits matter. Static analysis does not establish runtime load order
or whether a conditional use executes. Qualified declaration owners are stabilized before lookup;
if they do not stabilize within eight index passes, the project contributes imports only and its
constant uses are counted as unresolved.

In expanded mode, an import and a constant use between the same files produce one logical edge.
Its `import_kinds`
includes `:constant_reference`; `edge.evidence` and JSON graph exports retain the referenced name,
source span, and definition line for constant uses. Import evidence retains its call span. CSV,
HTML, and diagram reports use the same merged graph; CSV/HTML distinguish dependency kinds.
`# archunit: ignore` continues to suppress imports only, not constant references. Import-only mode
leaves `edge.evidence` empty for compatibility with existing edge-value comparisons;
`ArchUnit::Extraction.extract_imports` retains call locations in both modes.

For diagnostics, pass an `ArchUnit::Extraction::ExtractionProfile` to
`ArchUnit::Extraction.extract_graph(root, options: options, profile: profile)`. Its counters include
`unresolved_imports`, `unresolved_constant_references`, and `ambiguous_constant_references`; unknown
third-party constants do not become architecture violations. These counts describe a cold analysis;
a cache hit does not rerun diagnostics. Included malformed Ruby now raises
`ArchUnit::SourceParseError < ArchUnit::TechnicalError` in both modes and in AST metrics, rather
than silently returning a partial graph or zero counts. Its immutable `diagnostics` contain
`path`, one-based `line` and `column`, and the parser `message`; the extraction profile increments
`malformed_files`. Fix or explicitly exclude invalid files using the project source policy.
Fluent rule selectors do not limit graph discovery. Failed graph builds are not cached; after
editing previously cached valid source, the normal explicit `clear_cache: true` policy still applies.
This intentionally changes the prototype's permissive behavior before the stable release.

Expanded analysis uses a bounded Prism index and adds no runtime dependency. The design spike
considered [RubyDEX](https://github.com/Shopify/rubydex), whose semantic index is broader but adds a
Rust/native extension and platform packaging requirements. Reusing our existing Prism parser keeps
the Ruby 3.3/3.4/4.0 Windows/Linux support contract; each included source is parsed once per graph
build. A later semantic backend can broaden the documented lookup subset. Lookup fixtures follow
the [Ruby constant-scope documentation](https://docs.ruby-lang.org/en/master/syntax/modules_and_classes_rdoc.html#label-Constants).

Repositories containing multiple gems are discovered statically: every `*.gemspec` beneath the
project root contributes its adjacent existing `lib` directory to feature resolution. Gemspecs are
never evaluated. Add non-standard source roots explicitly through the per-check options bag; paths
are relative to the project root, must remain inside it, and use the order given after the normal
top-level `lib` and project-root search locations:

~~~ ruby
options = ArchUnit::CheckOptions.new(
  load_paths: ['components/billing/source', 'plugins/search/lib']
)

violations = rule.check(options)
report = ArchUnit.project_graph.with_check_options(options)
~~~

Load-path choices and dependency-analysis mode affect graph caching. Equivalent normalized choices
reuse a cached graph, while a different mode or load-path set builds a separate graph. Use
`clear_cache: true` after changing files, constant definitions, or gemspec
layout within one process.

## 🐲 Example Repository

The [ArchUnitRuby RAG test repository](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG)
is a small layered retrieval-augmented-generation application with two deliberate architecture
violations. Its test suite exercises the public APIs above against real Ruby source on Linux and
Windows.

ArchUnitRuby also dogfoods itself in `spec/architecture_spec.rb`: `common` is isolated, domain
modules cannot depend on one another, implementation files cannot depend on the public surface, and
the complete library graph must remain cycle-free.

## 🦊 Contributing

Start with [CONTRIBUTING.md](CONTRIBUTING.md) for the complete development and pull-request guide.

~~~ bash
git clone https://github.com/LukasNiessen/ArchUnitRuby.git
cd ArchUnitRuby
bundle install
bundle exec rake
bundle exec rake docs
gem build archunit.gemspec --strict
~~~

`bundle exec rake` validates release metadata, then runs the randomized RSpec suite and RuboCop.
CI additionally enforces 98% line
and 90% branch coverage, runs the dogfooding rules explicitly, builds the documentation, loads the
public API with Ruby warnings, tests optional RSpec/Minitest integrations, builds and installs the
gem artifact, runs the external RAG fixture, and checks Ruby 3.3, 3.4, and 4.0 across Ubuntu and
Windows.

Cold and warm extraction can be profiled independently with a generated multi-gem corpus. The
benchmark reports stage timings, resolution-cache effectiveness, Ruby heap growth, and peak RSS on
platforms that expose it:

~~~ bash
bundle exec ruby benchmark/extraction.rb
~~~

See the [benchmark guide](https://github.com/LukasNiessen/ArchUnitRuby/blob/main/benchmark/README.md)
for corpus controls, JSON output, and CI limits.

The separate [real-world canary](https://github.com/LukasNiessen/ArchUnitRuby/blob/main/benchmark/canary/README.md)
checks pinned Rack, Rake, and RSpec production-library sources in both dependency modes, including
passing and deliberately failing rules, graph baselines, and cold/warm performance. It never runs
those projects or installs their dependencies, and is not scheduled automatically yet.

The implementation conventions and intended dependency directions live in [`AGENTS.md`](AGENTS.md).

## 📅 Plans and Current Limitations

- Files are the primary vocabulary; opt-in constant analysis has the lookup limits described above.
- Runtime-derived import paths cannot be resolved; safely known local literal strings are supported.
- PlantUML support is a deliberately small component-diagram subset, not a complete UML parser.
- `.archignore` supports exclusion globs, not negated gitignore patterns or nested ignore files.
- Cycle traversal is iterative and tested on 10,000-node chains and rings. Enumerating every cycle
  can still be expensive in densely connected graphs; narrow the selected scope when necessary.
- The API is still pre-release and may change before the first stable gem version.

## 💟 Community

### Maintainers

- **[Tristan Kruse](https://github.com/TristanKruse)** — Tech Lead & Maintainer
- **[Lukas Niessen](https://github.com/LukasNiessen)** — Maintainer

### Contributors

See everyone who has contributed on the [GitHub contributors page](https://github.com/LukasNiessen/ArchUnitRuby/graphs/contributors).

Questions and feature ideas are welcome in [GitHub Issues](https://github.com/LukasNiessen/ArchUnitRuby/issues).
For usage help, responsible vulnerability reporting, and community expectations, see
[SUPPORT.md](SUPPORT.md), [SECURITY.md](SECURITY.md), and [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

### Star History

[![Star History Chart](https://api.star-history.com/svg?repos=LukasNiessen/ArchUnitRuby&type=Date)](https://star-history.com/#LukasNiessen/ArchUnitRuby&Date)

## 📄 License

[MIT](LICENSE)

<div align="right">

[Go back to the top](#top)

</div>
