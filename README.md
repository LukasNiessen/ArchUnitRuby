# ArchUnitRuby

Architecture testing for Ruby. Part of **ArchUnitEverything** — one architecture-testing library per language.

> Early development. Nothing to install yet.

Siblings: [ArchUnitTS](https://github.com/LukasNiessen/ArchUnitTS) ·
[ArchUnitPython](https://github.com/LukasNiessen/ArchUnitPython)

[![CI](https://github.com/LukasNiessen/ArchUnitRuby/actions/workflows/ci.yml/badge.svg)](https://github.com/LukasNiessen/ArchUnitRuby/actions/workflows/ci.yml)
[![Ruby 3.3+](https://img.shields.io/badge/Ruby-3.3%2B-CC342D?logo=ruby&logoColor=white)](https://www.ruby-lang.org/)
[![GitHub stars](https://img.shields.io/github/stars/LukasNiessen/ArchUnitRuby.svg)](https://github.com/LukasNiessen/ArchUnitRuby)

ArchUnitRuby analyzes a Ruby project as a directed dependency graph. The finished library will let
teams express architecture rules as ordinary RSpec or Minitest tests, keeping dependency direction,
layers, cycles, naming conventions, diagrams, and metrics executable in CI.

## Current status

ArchUnitRuby is a working **extraction prototype**, not a released end-user library yet. The full
source-to-graph path runs today; the fluent rule API is the next major part of the build.

| Capability | Status |
| --- | --- |
| Project discovery through a directory, `Gemfile`, or gemspec | Working |
| Ruby source enumeration with configurable exclusions | Working |
| Static `require`, `require_relative`, `autoload`, and `load` extraction | Working |
| Internal and external dependency classification | Working |
| Self-edges and parallel-edge merging | Working |
| Immutable graph values and graph caching | Working |
| File, layer, slice, metric, and graph-report rules | Planned |
| RSpec and Minitest assertion helpers | Planned |
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

## Target fluent API

The public rule-building API is under development. Its intended shape is an English sentence read
from left to right:

```ruby
# Preview only — this fluent API is not implemented yet.
rule = project_files
         .in_folder('app/api/**')
         .should_not
         .depend_on_files
         .in_folder('app/database/**')

expect(rule).to pass
```

Rules will be immutable values. Building a rule will do no filesystem work; the terminal check will
perform extraction and return structured violations rather than raising for architecture failures.

## Example repository

The [ArchUnitRuby RAG test repository](https://github.com/TristanKruse/ArchUnitRuby-TestRepo-RAG)
is an executable layered retrieval-augmented-generation fixture. It contains realistic dependencies,
two intentional architecture violations, application tests, architecture extraction tests, and its
own cross-platform CI workflow.

The fixture proves the current prototype end to end: project discovery, source enumeration, import
resolution, graph assembly, internal/external classification, caching, and deliberate violations.

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

CI runs the test suite, RuboCop, and gem build on every push and pull request. The project follows
the conventions in [`AGENTS.md`](AGENTS.md); Ruby idioms win where a sibling language's design does
not fit naturally.

## Roadmap and limitations

The build backlog lives in [GitHub Issues](https://github.com/LukasNiessen/ArchUnitRuby/issues).
Extraction and graph assembly are complete through issue #11. The next critical-path work covers an
optional per-line ignore directive and the shared projection layer used by file, layer, and slice
rules.

Not implemented yet:

- the fluent file, layer, slice, metric, and graph-report APIs;
- cycle projection and architecture assertions;
- RSpec's `pass` matcher and Minitest's `assert_passes` helper;
- RubyGems publication and stable installation instructions;
- diagram validation, reporting, logging, and metrics.

Until those pieces land, treat the gem as an actively developed prototype and use the direct graph
API only for experimentation.
