# Real-world static canary

The canary statically analyzes the **production `lib` directory only** of three pinned Ruby
repositories. It does not install their dependencies, evaluate their Gemfiles or gemspecs, execute
their source, or run their tests. It is not an upstream architecture-quality judgment.

| Corpus | Pinned revision | Ruby files | Internal edges: imports / expanded |
| --- | --- | ---: | ---: |
| [Rack](https://github.com/rack/rack) 3.2.6 | `e1f22fdbe99afd2126b6fbf05bb12399359574b7` | 49 | 133 / 140 |
| [Rake](https://github.com/ruby/rake) snapshot | `15df62f11e7f3980bb404bf1471e326cb7ad40ec` | 44 | 57 / 78 |
| [RSpec Core](https://github.com/rspec/rspec-core) snapshot | `aec5f49485d97908183dbe790a7fefb8baaa8091` | 74 | 18 / 157 |

These are reviewed baselines recorded on 2026-10-22, not moving branch names. `projects.json`
records the full commits, a known import witness, and per-mode file/edge counts and graph hashes.
The workflow matrix must match that manifest; an offline contract test enforces it.

## What it proves

For both `imports` and `imports_and_constants`, the canary:

- Confirms the exact checkout revision and a clean `lib` source scope.
- Measures cold extraction, warm cache reuse, stage timings, and available heap/RSS counters.
- Compares file counts, internal/external edge counts, and a sorted internal graph fingerprint.
- Runs a passing public rule, then deliberately forbids one known real import and requires exactly
  one `FileDependencyViolation` and an assertion failure containing the rule rationale.

For example, the Rack witness is `rack.rb -> rack/builder.rb`, relative to its `lib` root. Forbidding
this existing edge is an intentionally failing **test policy**, not evidence that Rack's design is wrong.
Unknown dynamic imports, unresolved constants, and ambiguous names remain visible in profile counters;
the canary does not claim complete modeling of Ruby or framework autoloading.

## Run it

After cloning a corpus and checking out the exact manifest commit:

~~~bash
bundle exec ruby benchmark/real_world_canary.rb \
  --project rack --root /path/to/rack \
  --output pkg/canary-rack.json
~~~

Corpus dependencies are never needed. The script uses ArchUnitRuby's own locked parser dependencies.
Do not run `bundle install` or build tasks inside the corpus. Dirty or untracked files under `lib`
are rejected; unrelated upstream test fixtures are outside the analysis scope. Some security test
fixtures can trigger host antivirus products. Do not disable those protections or attempt alternate
reads of blocked files: keep the declared source scope consistent across platforms.

The separate **Real-world static canary** workflow runs on relevant pull requests and supports manual
dispatch once merged. It is intentionally not scheduled yet. It uses read-only repository access,
three isolated ten-minute jobs, and 14-day JSON artifacts, including error evidence on failures.
Keep it advisory rather than adding it to required branch checks until its cost and stability are reviewed.
Failures remain red; they are not hidden with `continue-on-error`.

There are broad 120-second cold / 5-second warm ceilings per mode, plus the job timeout. Those are
runaway guards, not performance promises. Local cold times for this lib-only corpus were roughly
0.1–0.4 seconds per mode on Ruby 4.0.6 / Windows x64; compare repeated like-for-like samples before
claiming a speedup. These small libraries are not substitutes for a full Rails monorepo benchmark.

## Updating a baseline

1. Choose and review a new full upstream commit. Update the workflow matrix and manifest together.
2. Inspect the known witness in that source. Do not replace it with an arbitrary edge simply to pass.
3. Run the script with `--record` to produce **proposed observations**. This option never rewrites the
   manifest and marks its report `baseline_verified: false`.
4. Review file/edge/hash differences and unresolved/ambiguous counters. If the extractor changed,
   determine whether differences are intended or a regression before accepting new expectations.
5. Edit the reviewed `modes` values in `projects.json`, rerun without `--record`, and verify Linux CI.

Regular CI never records or automatically accepts a new baseline. The ordinary unit suite uses
small synthetic projects and mocked git inspection; it does not clone these repositories or need a network.
