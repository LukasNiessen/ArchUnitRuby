# ArchUnitRuby

Architecture testing for Ruby. Part of **ArchUnitEverything**: one recognizable testing library
for each programming language.

[![CI](https://github.com/LukasNiessen/ArchUnitRuby/actions/workflows/ci.yml/badge.svg)](https://github.com/LukasNiessen/ArchUnitRuby/actions/workflows/ci.yml)
[![Documentation](https://img.shields.io/badge/docs-GitHub%20Pages-e4493f)](https://lukasniessen.github.io/ArchUnitRuby/)
[![Gem version](https://img.shields.io/gem/v/archunit.svg)](https://rubygems.org/gems/archunit)
[![Gem downloads](https://img.shields.io/gem/dt/archunit.svg)](https://clickgems.clickhouse.com/dashboard/archunit)
[![Ruby 3.3+](https://img.shields.io/badge/Ruby-3.3%2B-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/LukasNiessen/ArchUnitRuby.svg)](https://github.com/LukasNiessen/ArchUnitRuby)

ArchUnitRuby turns a Ruby codebase into a dependency graph and lets you test that graph with rules
that read like English:

```ruby
ArchUnit.project_files
        .in_folder('app/api/**')
        .should_not.depend_on_files
        .in_folder('app/database/**')
```

It is a working executable prototype with file, layer, slice, graph-reporting, and metric APIs. It
is tested on Ruby 3.3, 3.4, and 4.0 on Linux and Ruby 4.0 on Windows. Version 0.0.1 is available as
[`archunit`](https://rubygems.org/gems/archunit) on RubyGems.

Siblings: [ArchUnitTS](https://github.com/LukasNiessen/ArchUnitTS) and
[ArchUnitPython](https://github.com/LukasNiessen/ArchUnitPython).

## Documentation

The [documentation site](https://lukasniessen.github.io/ArchUnitRuby/) combines this guide with a
searchable, source-generated API reference for every public module, class, and method. The same
site is rebuilt in CI and deployed from `main`, so the published reference follows the repository.

## Install

ArchUnitRuby requires Ruby 3.3 or newer. Add it to your test dependencies:

```ruby
# Gemfile
group :test do
  gem 'archunit', '~> 0.0.1'
end
```

Then install it:

```bash
bundle install
```

Or install it directly with `gem install archunit`.

[ClickGems download analytics](https://clickgems.clickhouse.com/dashboard/archunit) show trends by
date, gem version, Ruby version, system, and country. Download totals count package fetches rather
than unique users, so repeated installs and automated clients may contribute to the total. The
[RubyGems API](https://rubygems.org/api/v1/gems/archunit.json) provides the
current raw count and ClickGems provides the historical breakdown.

RSpec and Minitest integrations are optional; ArchUnitRuby does not install either test framework
for you.

## Your first rule

Create `spec/architecture_spec.rb`:

```ruby
require 'archunit'

RSpec.describe 'architecture' do
  it 'keeps the API away from the database' do
    rule = ArchUnit.project_files.in_folder('app/api/**')
                   .should_not.depend_on_files.in_folder('app/database/**')

    expect(rule).to pass
  end
end
```

Run it like any other specification:

```bash
bundle exec rspec spec/architecture_spec.rb
```

The project locator is optional. With no argument, ArchUnitRuby searches from the current directory
for a `Gemfile` or gemspec. Pass a directory or either marker file when analyzing another project:

```ruby
ArchUnit.project_files('/workspace/my_app')
ArchUnit.project_files('/workspace/my_app/Gemfile')
```

## The fluent grammar

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

```ruby
services = ArchUnit.project_files.in_folder('app/services/**')

cycle_rule = services.should.have_no_cycles
database_rule = services.should_not.depend_on_files.in_folder('app/database/**')
```

String patterns are anchored globs. `*` stays inside one path segment, `**` crosses directories,
and `?` matches one non-separator character. Most selectors also accept regular expressions;
`defined_by_regex` is the explicit regex form for slices, while `in_file` takes one exact path.
Paths are project-relative and normalized to `/` separators.

A scope matching zero files returns `EmptyTestViolation`; it does not silently pass. Opt out only
when an empty result is genuinely valid:

```ruby
rule.check(ArchUnit::CheckOptions.new(allow_empty_tests: true))
```

## Files

File rules cover cycles, naming, location, internal dependencies, external modules, and custom
source predicates:

```ruby
rules = [
  ArchUnit.project_files.in_path('lib/**/*.rb').should.have_no_cycles,
  ArchUnit.project_files.in_folder('app/services/**')
          .should.have_name('*_service.rb'),
  ArchUnit.project_files.in_folder('app/domain/**')
          .should_not.depend_on_external_modules.matching('faraday')
]

rules.each { |rule| ArchUnit.assert_passes(rule) }
```

A custom predicate receives an immutable `FileInfo` with `path`, `name`, `extension`, `directory`,
complete `content`, and non-blank `lines_of_code`:

```ruby
rule = ArchUnit.project_files.in_folder('app/services/**')
               .should.adhere_to(
                 ->(file) { file.lines_of_code < 300 },
                 'services must stay below 300 non-blank lines'
               )
```

## Layers

Named layers express an allowlist or blocklist over groups of files:

```ruby
rule = ArchUnit.project_layers
               .layer('api').defined_by('app/api/**/*.rb')
               .layer('services').defined_by('app/services/**/*.rb')
               .layer('database').defined_by('app/database/**/*.rb')
               .where_layer('api').may_only_depend_on_layers('services')
               .where_layer('services').may_only_depend_on_layers('database')
               .where_layer('database').may_only_depend_on_layers

expect(rule).to pass
```

Dependencies within one layer are always allowed. Edges with an unassigned endpoint are ignored.
Calling `may_only_depend_on_layers` without targets seals a layer; `may_not_depend_on_layers`
requires at least one forbidden target.

## Slices and PlantUML

Slices group files by one captured path segment and preserve every concrete dependency as evidence:

```ruby
slices = ArchUnit.project_slices.defined_by('lib/my_app/(**)/')
rule = slices.should_not.contain_dependency('api', 'database')

expect(rule).to pass
```

`(**)` is the slice capture. `defined_by_regex` uses the first regular-expression capture instead.

A checked-in PlantUML component diagram can also be the architecture contract:

```ruby
rule = slices.should
             .ignoring_external_slices
             .adhere_to_diagram_in_file('docs/architecture.puml')

expect(rule).to pass
```

The supported subset recognizes components, directed dependencies, comments, and `@startuml` /
`@enduml`. Use `to_plantuml` or `export_as_plantuml(path)` to generate a diagram from the real graph.

## Dependency graph reports

Graph reporting builds one immutable snapshot and renders it consistently as DOT, Mermaid, D2, CSV,
JSON, or self-contained HTML:

```ruby
report = ArchUnit.project_graph
                 .include_external_dependencies
                 .focus_on('app/services/**', 2)
                 .collapse_to_folder_depth(2)
                 .titled('Service dependencies')

puts report.summary.node_count
report.export_as_html('reports/services.html')
```

Queries include `focus_on`, `reachable_from`, and `dependents_of`. Collapse by folder depth or a
regular-expression replacement. Every format has an in-memory `to_<format>` and an
`export_as_<format>(path)` terminal.

## Metrics

Metric scopes select files and Ruby classes before measurement or assertion:

```ruby
services = ArchUnit.metrics
                   .in_path('app/services/**/*.rb')
                   .for_classes_matching('*Service')

size_rule = services.count.method_count.should_be_below_or_equal(20)
cohesion_rule = services.lcom.lcom4.should_be(1)
distance_rule = services.distance.instability.should_be_below(0.8)

[size_rule, cohesion_rule, distance_rule].each { |rule| ArchUnit.assert_passes(rule) }
```

Count metrics cover class methods and fields plus file lines, statements, imports, classes, and
top-level functions. Cohesion includes LCOM96a, LCOM96b, LCOM1-5, and LCOM*. Dependency-derived
metrics include abstractness, instability, main-sequence distance, coupling factor, and normalized
distance. Zone guards detect the conventional zones of pain and uselessness.

Use `measure` for immutable numeric results, `custom_metric` for a calculation over `ClassInfo`, and
`export_as_html` for an offline metrics report:

```ruby
services.count.export_as_html('reports/service-counts')
```

The threshold vocabulary is intentionally limited to `should_be_below`, `should_be_above`,
`should_be`, `should_be_below_or_equal`, `should_be_above_or_equal`, and `should_satisfy`.

## Pattern exclusions

Every selector accepts `except:` in the same call. A plain pattern or array uses the parent
selector's context, including filenames for path and folder selectors:

```ruby
scope = ArchUnit.project_files.in_path(
  'app/**/*.rb',
  except: ['app/generated/**', 'schema.rb']
)
```

Use explicit targets when needed. Supported keys are `in_path`, `in_folder`, `with_name`, and
`for_classes_matching`:

```ruby
scope = ArchUnit.metrics.in_path(
  'app/**/*.rb',
  except: { in_folder: 'app/generated', with_name: '*_spec.rb' }
)
```

## Results and test frameworks

`check` returns an array of structured violations. Architecture disagreement is data, not an
exception:

```ruby
violations = rule.check
violations.each { |violation| puts violation.class }
```

Translate that result into a test failure at the boundary that suits your suite:

```ruby
expect(rule).to pass              # RSpec
assert_passes(rule)               # Minitest test case
ArchUnit.assert_passes(rule)      # Framework-neutral
```

`ArchUnit.format_violations` and `ResultFactory` provide stable human-readable output. All
violations retain the concrete dependency, file, layer, slice, or metric evidence that caused them.

## Per-check logging

Logging is off by default and belongs to one check; there is no process-global configuration:

```ruby
logging = ArchUnit::LoggingOptions.new(
  level: :debug,
  output_directory: 'tmp/archunit-logs',
  append: false
)

violations = rule.check(ArchUnit::CheckOptions.new(logging: logging))
```

Levels are `debug`, `info`, `warn`, and `error`. The fixed events cover check start/end, progress,
violations, and metric evidence. `io:` defaults to `$stderr`, accepts any writable stream, and may be
`nil`. File output creates missing directories and writes timestamped `archunit-*.log` files.

## What ArchUnitRuby extracts

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

```ruby
require 'legacy/client' # archunit: ignore legacy/client

# archunit: ignore experimental/plugin
require 'experimental/plugin'
```

Dynamic imports such as `require dependency_name` or `require "plugins/#{name}"` are omitted rather
than guessed because resolving them would require executing application code.

## Executable examples

The [ArchUnitRuby RAG test repository](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG)
is a small layered retrieval-augmented-generation application with two deliberate architecture
violations. Its test suite exercises the public APIs above against real Ruby source on Linux and
Windows.

ArchUnitRuby also dogfoods itself in `spec/architecture_spec.rb`: `common` is isolated, domain
modules cannot depend on one another, implementation files cannot depend on the public surface, and
the complete library graph must remain cycle-free.

## Development

```bash
git clone https://github.com/LukasNiessen/ArchUnitRuby.git
cd ArchUnitRuby
bundle install
bundle exec rake
bundle exec rake docs
gem build archunit.gemspec --strict
```

`bundle exec rake` runs the randomized RSpec suite and RuboCop. CI additionally enforces 98% line
and 90% branch coverage, runs the dogfooding rules explicitly, builds the documentation, loads the
public API with Ruby warnings, tests optional RSpec/Minitest integrations, builds and installs the
gem artifact, runs the external RAG fixture, and checks Ruby 3.3, 3.4, and 4.0 across Ubuntu and
Windows.

The implementation conventions and intended dependency directions live in [`AGENTS.md`](AGENTS.md).

## Current limitations

- Ruby constants are not modeled as a separate graph. Files are the primary dependency vocabulary.
- Dynamic `require`, `autoload`, and `load` arguments cannot be resolved statically.
- PlantUML support is a deliberately small component-diagram subset, not a complete UML parser.
- The API is still pre-release and may change before the first stable gem version.

## License

[MIT](LICENSE)
