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

