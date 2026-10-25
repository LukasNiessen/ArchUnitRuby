# Stable-release readiness

All four currently open feature issues (#47, #48, #54, #55) have implementations in the pending
PR stack. They are not considered shipped until those changes reach `main` and a gem is published.

## Before 1.0.0

- Merge the reviewed integration work and the rationale/exclusion PRs in dependency order. Retarget
  stacked PRs to `main` after their base merges. Do not bypass the existing branch protections.
- Merge the pre-v1 audit fixes and rerun the entire matrix on `main`: supported Ruby versions,
  Windows/Linux, coverage, lint, dogfooding, documentation links, installed-gem checks, and the RAG fixture.
- Keep the import-only default and the explicit `imports_and_constants` opt-in documented. Unknown
  runtime behavior, ambiguous constants, and dynamic import paths are not a complete Ruby interpreter.
- Review representative passing and failing rules manually. Include a constant-only forbidden edge,
  a safely inferred import, a `.because(...)` failure, and `.archignore` exclusions.
- Set the version to `1.0.0`, refresh the local gem lock entry, date the changelog, update installation
  instructions, and replace prototype/pre-release wording with an accurate stable API contract.
- Run `bundle exec ruby scripts/check_release_metadata.rb --release`; development checks alone
  intentionally do not prove publication readiness.
- Run `bundle exec rake security` with a freshly updated advisory database and review the JSON
  evidence. Resolve actionable findings; do not add unexplained advisory ignores to pass CI.
- Publish only after maintainer approval via the trusted-publisher workflow. Install the published
  version in a clean project and rerun a passing/failing architecture example before announcing it.

## Audit coverage added

- 10,000-node chains, directed rings, and unblock cascades; deterministic mutual-reachability and
  exhaustive small-graph oracles protect the iterative algorithms' correctness.
- Source symlinks inside/outside the project, broken links, directory links, canonical file boundaries,
  and incompatible-volume errors. Native-link tests run on Linux; portable boundary tests also run
  on Windows hosts without symlink privileges.
- Metadata consistency and strict release gating, inspired by ArchUnitPython's existing metadata
  validation. Unlike automatic sibling publishing, Ruby publication remains a deliberate dispatch.

These are targeted regression tests, not a claim that every bug has been found or a security
certification. Analysis does not execute application code, but it is not an OS-level sandbox for
an actively changing or hostile filesystem. Dense graphs can have exponentially many cycles.

## Next useful improvements

- Establish repeated real-world performance baselines on pinned Ruby repositories before setting
  tighter thresholds. Report cold analysis, warm cache reuse, graph contents, and memory separately.
- Add an opt-in, non-blocking real-world canary once the repository set and update policy are agreed.
- Dependency vulnerability scanning is available as a separate task/workflow. Consider mutation
  testing as another measured addition; high line coverage is not proof of semantic correctness.
