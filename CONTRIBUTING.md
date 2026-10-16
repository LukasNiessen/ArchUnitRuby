# Contributing to ArchUnitRuby

Thank you for helping improve the Ruby member of the ArchUnitEverything family. Small, focused
changes with tests are easiest to review.

## Before opening a change

- Search the [existing issues](https://github.com/LukasNiessen/ArchUnitRuby/issues).
- Use an issue for behavior changes or larger additions so the Ruby API can stay aligned with the
  sibling implementations.
- Read [AGENTS.md](AGENTS.md) for architecture, naming, and fluent-API conventions.
- Never include credentials, private project source, or customer data in an issue or fixture.

## Development setup

ArchUnitRuby requires Ruby 3.3 or newer.

~~~bash
git clone https://github.com/LukasNiessen/ArchUnitRuby.git
cd ArchUnitRuby
bundle install
bundle exec rake
~~~

`bundle exec rake` runs the randomized RSpec suite and RuboCop. Before submitting documentation or
public API changes, also run:

~~~bash
COVERAGE=true bundle exec rspec
bundle exec rake docs
gem build archunit.gemspec --strict
~~~

The coverage suite enforces at least 98% line and 90% branch coverage. The documentation task builds
the complete site, checks the public API guide, rejects unrendered Markdown, and validates internal
links.

## Design expectations

- Write the fluent sentence first and read it aloud.
- Prefer idiomatic Ruby when a sibling convention conflicts with the language.
- Keep builders immutable and lazy; only terminals perform analysis.
- Return structured violations for architecture disagreements—do not raise until the assertion
  boundary.
- Add a focused unit test and an end-to-end fluent API test for behavior changes.
- Keep `# frozen_string_literal: true` in Ruby files and leave RuboCop clean.
- Update `README.md`, `API.md`, and `CHANGELOG.md` when public behavior changes.

## Pull requests

A useful pull request explains the user-facing problem, the chosen behavior, any deliberate
cross-language difference, and how it was tested. Please keep unrelated formatting or refactors out
of the same change.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md). Security reports
must follow [SECURITY.md](SECURITY.md), not a public issue.

