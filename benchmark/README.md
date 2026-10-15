# Extraction performance benchmark

The benchmark generates a deterministic multi-gem Ruby repository, then measures one cold graph
build and one same-process cached lookup. Target application code and generated gemspecs are never
executed.

Run the default 1,000-file corpus:

```bash
bundle exec ruby benchmark/extraction.rb
```

The corpus includes a declared class and a cross-file constant use per generated source. Compare
import-only extraction against expanded indexing on identical source with:

```bash
bundle exec ruby benchmark/extraction.rb --constants
```

Both runs report cold/warm timing and memory. Expanded runs also report `constant_indexing`,
unresolved/ambiguous-reference counters, and the same-process graph cache reuse result.

Use a smaller CI smoke corpus with deliberately generous, non-flaky limits:

```bash
bundle exec ruby benchmark/extraction.rb \
  --files 200 --gems 4 --imports-per-file 3 \
  --max-cold-seconds 30 --max-warm-seconds 2
```

The JSON output reports wall-clock time for project discovery, source enumeration, load-path
discovery, file reads, Prism parsing, import extraction, target resolution, edge merging, and the
complete run. Internal-target indexing and edge classification are reported separately so hidden
filesystem work cannot disappear between the larger stages. Counters expose source/import/edge
totals and feature-resolution cache hits. Memory
output includes Ruby heap growth on every platform and process peak RSS where `/proc` exposes it.

`--output path.json` also saves the complete result. Hosted CI only uses the smoke corpus and broad
regression ceilings; performance decisions should use several local runs of the default corpus or a
non-blocking real-world canary.

## Constant-analysis measurement

On 2026-10-15, Ruby 4.0.6 on Windows x64, three fresh-process runs per mode on the updated
1,000-file / 10-gem corpus produced these medians:

| Measurement | Imports | Imports and constants |
| --- | ---: | ---: |
| Cold graph build | 1.959 s | 2.019 s |
| Warm graph lookup | 3.23 ms | 2.62 ms |
| Constant indexing/resolution | — | 42.8 ms |
| Merged graph edges | 4,001 | 4,001 |

All runs reused the identical cached graph on their warm lookup. The corpus references the same
next file by import and constant, so expanded mode merges 5,001 raw edges into 4,001 edges while
retaining both evidence forms. Every source is parsed once per cold graph. The roughly 3% median
cold-time increase is a local observation, not a portable overhead guarantee.

Heap-growth samples ranged from 4.18–5.55 MB for imports and 5.51–14.19 MB for expanded analysis;
these pre-GC snapshots are sensitive to collection timing and do not establish retained or peak
memory. Windows does not expose the Linux peak-RSS counter. ASTs and indexing structures are
temporary; the cached graph retains immutable edges and evidence only.

## Reference baseline and target

On 2026-08-14, Ruby 4.0.6 on the Windows development machine produced the following default-corpus
results. The optimized values are the median of three fresh processes:

| Measurement | Before indexed/cached canonicalization | Current |
| --- | ---: | ---: |
| Cold extraction | 25.841 s | 6.388 s |
| Warm graph lookup | 9.95 ms | 6.17 ms |
| Ruby heap growth | 4.94 MB | 3.08 MB |
| Graph edges | 4,001 | 4,001 |

The cold improvement is approximately 75.3%, with identical graph semantics. The local regression
target for this corpus is therefore a three-run median below 15 seconds cold and 50 milliseconds
warm on comparable hardware. These are reference targets, not portable promises; CI deliberately
uses the much broader 200-file ceilings shown above.

As a real-world diagnostic, Rails at commit `ef8d960` contained 3,444 analyzed Ruby files and 6,560
literal imports. On the same Windows development checkout, profiled extraction took 33.6 seconds
and produced 9,913 graph edges. Source enumeration (11.7 seconds), target resolution (7.1 seconds),
and Prism parsing (6.7 seconds) dominated; the resolution cache served 4,872 repeated lookups. A
first pass against a completely cold Windows filesystem was much slower, so this is diagnostic data,
not a portable regression threshold. Native or safely pruned source enumeration is the clearest
next performance investigation.
