# Generate and validate descriptors

Invoke `scripts/contracts.py` from this skill's directory. It uses pinned
`jsonschema` and `PyYAML` dependencies through uv. The first run may populate
uv's dependency cache. Subsequent runs can use `UV_OFFLINE=1`; JSON Schemas are
bundled and validation does not retrieve remote schemas.

Check dependencies and the CTB project environment:

```bash
scripts/contracts.py check --ctb-root /path/to/ctb
scripts/contracts.py unit-test
```

Generate ODCS and ODPS drafts from the current daily-candle runtime schema:

```bash
scripts/contracts.py generate --ctb-root /path/to/ctb --owner NostraDavid --output-dir /tmp/ctb-contracts --dry-run
scripts/contracts.py generate --ctb-root /path/to/ctb --owner NostraDavid --output-dir /tmp/ctb-contracts
```

Generation uses CTB's existing `ctb-bitvavo/.venv/bin/python` to inspect
`DAILY_SCHEMA` and the quality/freshness enums. The imported source must belong
to the specified checkout. Synchronize that environment through CTB's normal
workflow if needed. It preserves exact decimals, UTC millisecond timestamps,
nullable OHLCV and the composite key. Unsupported types or changed decimal/UTC
invariants fail rather than receiving a guessed mapping. New fields default to
nullable until their semantics are reviewed.

The command creates `daily-candles.odcs.yaml` and `daily-candles.odps.yaml`,
validates them before writing, and refuses to overwrite existing files. Use
`--contract-id`, `--product-id`, and `--version` for explicit identities and
versions; defaults are new UUIDv7 identities and descriptor version `1.0.0`.
Descriptions and access paths still need review. No SLA or server is invented.

Validate YAML or JSON descriptors against the pinned standard schemas:

```bash
scripts/contracts.py validate /tmp/ctb-contracts/daily-candles.odcs.yaml /tmp/ctb-contracts/daily-candles.odps.yaml
scripts/contracts.py validate --ctb-root /path/to/ctb /tmp/ctb-contracts/daily-candles.odcs.yaml /tmp/ctb-contracts/daily-candles.odps.yaml
```

Supply every referenced contract, including input dependencies. Validation
rejects duplicate YAML keys, incorrect standard versions and duplicate contract
identities/versions. Quoted and unquoted YAML timestamps remain strings for JSON
Schema validation. Input- and output-port references must resolve to exactly one
local contract. If several retained versions share an ID, specify
`contractVersion` in the port's `customProperties`; port version is independent
of contract version. Generation records that metadata automatically. Input
dependencies resolve by ID and version.

`--ctb-root` additionally compares every supplied `daily_candles` definition to
current runtime fields, logical/physical types, nullability, composite-key
positions, and quality/freshness enums. Validate historical contracts without
this option when they deliberately describe an older runtime schema.

Success exits with code 0; validation, environment, or file errors use code 1;
CLI usage errors use code 2. `check` prints `ok` on success.
`generate --dry-run` prints validated YAML without creating files or
directories.

Schema validity and runtime agreement do not establish measured data quality,
freshness guarantees, access authorization or consumer compatibility. Review
those separately and reuse existing CTB pipeline tests.

## Schema sources

The bundled schemas are unmodified Bitol release files under Apache-2.0. The
license is in `assets/schemas/LICENSE`.

| File                 | Upstream revision                          | SHA-256                                                          |
| -------------------- | ------------------------------------------ | ---------------------------------------------------------------- |
| `odcs-v3.2.0.schema` | `f0bdad95346905d500be5ef4b2c2d9b1d95223b7` | edb41f33ec46e84780e99872ab2bd67f074959d2bf3e9c9fc54e61f8982b0d93 |
| `odps-v1.1.0.schema` | `04995037fc003ead1da27f65a40a09eb0664b591` | b7eae1af15b3c6b18e5dffaa2119212acb38ec73286933c76d16c8712e0d90d1 |

Sources:
[ODCS v3.2.0](https://github.com/bitol-io/open-data-contract-standard/blob/v3.2.0/schema/odcs-json-schema-v3.2.0.json)
and
[ODPS v1.1.0](https://github.com/bitol-io/open-data-product-standard/blob/v1.1.0/schema/odps-json-schema-v1.1.0.json).
Review schema upgrades explicitly together with ADR-SYS-0045.
