# Security Policy

## Supported versions

ArchUnitRuby is currently pre-1.0. Security fixes are applied to the latest published gem and the
`main` branch.

| Version | Supported |
| --- | --- |
| Latest `0.0.x` release | Yes |
| Older releases | No |

## Reporting a vulnerability

Please do not open a public issue for a suspected vulnerability. Use GitHub's
[private vulnerability reporting](https://github.com/LukasNiessen/ArchUnitRuby/security/advisories/new)
to share the affected version, impact, reproduction steps, and any suggested mitigation.

Do not include real credentials, private source code, or customer data. A minimal synthetic
reproduction is preferred. The maintainers aim to acknowledge a report within three business days
and will coordinate validation, remediation, release, and disclosure with the reporter.

## Security model

ArchUnitRuby statically reads Ruby source and gemspec text; it does not intentionally execute the
analyzed project or evaluate gemspecs. Dynamic import expressions are omitted instead of executed.
Run architecture analysis with the same filesystem permissions you would grant any test tool, and
review exported reports before sharing them because paths and dependency names may reveal project
structure.

## Locked dependency scanning

`bundle exec rake security` refreshes the public [Ruby advisory database](https://github.com/rubysec/ruby-advisory-db)
and scans this checkout's `Gemfile.lock` with [bundler-audit](https://github.com/rubysec/bundler-audit).
The scanner is a development dependency, not a runtime dependency of the published gem.

The separate dependency-security workflow runs on pull requests, pushes to `main`, manual dispatch,
and Mondays at 07:17 UTC after this workflow reaches the default branch. It has read-only repository
permissions, a ten-minute limit, and retains JSON evidence for 14 days even on failure. No automatic
advisory exceptions or dependency upgrades are applied.

The wrapper normalizes Windows database paths, rejects empty databases, and verifies detection of
a known-vulnerable synthetic lockfile before accepting a clean result. No vulnerable gem is installed
or executed for that health check. Failed database updates fail the scan rather than silently using
stale data. Reports include the advisory count and database commit.

For an explicitly offline repeat using an already downloaded database:

~~~bash
bundle exec ruby scripts/check_dependency_security.rb --no-update
~~~

The report is saved to `pkg/dependency-audit.json`; `--database PATH` and `--output PATH` override
locations. A clean scan means no matches in that database snapshot, not a security certification.
It does not audit Ruby itself, all versions allowed by the gemspec, or an application's unrelated
dependency lockfile. Default tests remain offline; only the separate security task refreshes data.

