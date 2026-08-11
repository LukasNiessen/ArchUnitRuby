# Releasing ArchUnitRuby

Releases use RubyGems trusted publishing. No long-lived RubyGems API key belongs in GitHub secrets.

## One-time RubyGems setup

Before the first release, the RubyGems account that should own `archunit` must create a pending
trusted publisher with these exact values:

| Field | Value |
| --- | --- |
| Gem name | `archunit` |
| Repository owner | `LukasNiessen` |
| Repository name | `ArchUnitRuby` |
| Workflow filename | `release.yml` |
| Environment | `release` |

Create it from <https://rubygems.org/profile/oidc/pending_trusted_publishers/new>. After the first
successful publication, RubyGems converts the pending publisher into the gem's trusted publisher
and makes that RubyGems account an owner.

## Publishing a version

1. Update `ArchUnit::VERSION` in `lib/archunit/version.rb` and add the release to `CHANGELOG.md`.
2. Ensure `main` is green and the README installation instructions match the version.
3. Run the `Release` workflow on the `main` branch and enter the version without a leading `v`.
4. The workflow verifies the version, tests and lints the project, validates documentation and the
   gem, publishes it, and creates and pushes the matching `v<version>` tag.
5. Install the version from RubyGems in an empty gem home and run `require 'archunit'` before
   announcing the release.

The workflow refuses to release from a branch other than `main` or when its version input differs
from `ArchUnit::VERSION`.
