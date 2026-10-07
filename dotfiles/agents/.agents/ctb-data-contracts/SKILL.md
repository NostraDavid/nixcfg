---
name: ctb-data-contracts
description: Draft, review, and validate Bitol ODCS contracts and ODPS products in CTB, including runtime-schema agreement, product references, and compatibility. Exclude trading advice and unrelated API contracts.
---

# Manage CTB data contracts and products

Work in a CTB checkout containing `ctb-bitvavo/` and `dagster-runtime/`. Read
`docs/adr/ADR-SYS-0045-use-odcs-and-odps-for-data-contracts-and-products.md` and
respect its current status and scope.

Start with the public Curated daily-candle product. Add other boundaries only
for a concrete producer-consumer dependency. Keep one product distinct from its
datasets, partitions, runs, and artifacts.

## Read the existing implementation

Inspect the owning runtime schema, producer, consumer, tests, and runbook. For
daily candles, start with:

- `ctb-bitvavo/src/ctb_bitvavo/curated.py`: `DAILY_SCHEMA`, publication and
  checks.
- `ctb-bitvavo/src/ctb_bitvavo/decimal_utils.py`: exact decimal representation.
- `ctb-bitvavo/src/ctb_bitvavo/query.py`: read behavior and unavailable days.
- `ctb-bitvavo/src/ctb_bitvavo/provenance.py`: artifact identity and lineage.
- `docs/runbooks/curated-daily-candles.md` and `read-curated-candles.md`.
- ADR-SYS-0018, 0027, 0029, 0030, 0043, and 0044 under `docs/adr/`.

Derive field names and physical types from code. Maintain meaning, owner,
limitations, and consumer expectations explicitly. Resolve disagreement between
an ADR's conceptual name and the physical schema: the current Parquet field is
`day_start`, not `day_start_utc`. Describe UTC semantics without renaming it.

Preserve Decimal(38,18), timezone-aware UTC millisecond timestamps, and the
composite `(market, day_start)` key. An empty day has nullable OHLCV; absence
does not imply zero trading. Keep quality, availability, freshness, coverage,
and daily/minute consistency distinct. An unavailable day need not have a row.
Verify these facts against current code rather than treating this list as a
replacement schema.

## Author or change descriptors

Use ODCS `apiVersion: v3.2.0` and ODPS `apiVersion: v1.1.0`. Read the bundled
schemas and [generation and validation commands](references/validation.md). ODCS
uses top-level `id`, `version`, `kind`, and a `schema` array containing objects
and `properties`.

Use `scripts/contracts.py generate` to create daily-candle drafts from CTB's
current runtime schema. Review and complete meaning, supported access paths, and
limitations before promoting drafts. For existing descriptors, preserve
identity, edit the relevant fields, and run `scripts/contracts.py validate`.

Keep reviewed descriptors with their owning code, following any existing layout.
Give them stable identities; use UUIDv7 where supported. Preserve identity when
editing and distinguish standard version, descriptor version, Git revision, and
artifact identity. Each ODPS output port references the appropriate contract.
Record which retained definition a versioned port exposes.

Describe Bitvavo input as observed expectations, not an agreement by Bitvavo.
Keep Raw unchanged when observations violate expectations. Record known sparse
coverage, stale fallback, and comparison discrepancies. Declare only supported
access paths and established service guarantees. Descriptors contain no
credentials, private payloads, or personal examples.

For changes, compare the old and new definitions and affected consumers. Review
field removal/rename, nullability, enums, decimal scale, timestamp units and
timezone, grain, and semantic meaning. Passing data tests does not prove
consumer compatibility. Retain old definitions for breaking changes and
reproducible rebuilds; preserve CTB's existing API compatibility policy.

## Validate and report

Run `scripts/contracts.py validate` on the affected descriptors and referenced
contracts. For daily candles, pass `--ctb-root` to compare field names, logical
and physical types, nullability, composite keys, and outcome enums against the
runtime policy. Review grain, outcome meanings, access paths, and compatibility
separately; descriptor validation does not establish those promises for data.

Reuse existing pipeline tests and quality checks for declared rules. When
runtime integration is authorized, expose checks through the existing Justfile
and quality gates. Record contract identity, version, and checksum in new
artifact provenance while preserving historical manifests. Keep measured results
and lineage in existing stores. Dagster remains the orchestration owner.

Report the affected product/contracts, standard and descriptor versions, checks
actually run, compatibility impact, and unresolved facts. Distinguish schema
validity, reference consistency, runtime agreement, and measured data quality.
If dependencies or evidence are unavailable, report the missing check.

For activation and task-quality measurements, use the
[evaluation procedure](references/evaluation.md).
