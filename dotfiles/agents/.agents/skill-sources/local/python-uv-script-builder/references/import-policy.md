# Import and Library Policy

## Enforcement split

- Read `import-policy.toml` as the canonical alias registry.
- Use the registered alias whenever importing a listed module. Prefer the first
  alias when multiple aliases are allowed; use another allowed alias only when
  it makes the surrounding code more coherent.
- Treat shared aliases such as `json`, `pa`, `st`, `lg`, `dbg`, `http`, and `ET`
  as alternatives. Do not import competing modules under the same name in one
  script.
- Let the validator enforce exact import syntax and aliases. Use language-model
  reasoning for library selection and API migration; changing only an import is
  not a safe migration between different libraries.
- Do not add Semgrep to generated scripts. Consider a generated Semgrep ruleset
  later only when the same checks must run repository-wide in CI.

## Preferred libraries

- Use Polars as `pl` instead of pandas. Use pandas as `pd` only when an external
  API genuinely requires pandas objects and convert at that boundary.
- Use Niquests as `http` instead of Requests or HTTPX.
- Import top-level `structlog as sl` as the configuration namespace and import
  `structlog.stdlib as log` as the typed logger namespace. Construct each module
  logger exactly as `logger = log.get_logger(__name__)`; rely on the public
  return type instead of adding an explicit annotation. Do not use another
  structlog alias or import structlog objects individually. Use standard logging
  as `lg` only for unavoidable compatibility bridges.
- Use `pydantic-settings` for environment and settings models. Import its public
  types directly because no module alias is registered.
- Use cachetools for caching. Use functools only for its non-caching utilities.
- Use orjson as `json` instead of standard-library JSON. Use simplejson as
  `json` only for a specific compatibility requirement.
- Use `pyarrow.parquet as pq` with `compression="zstd"` for fast binary tabular
  persistence. Use `zstandard as zstd` only when handling raw Zstandard streams
  outside Parquet.
- Use joblib instead of pickle when it can represent the data. Never load
  joblib or pickle data from an untrusted source.
- Use NumPy as `np` instead of math or statistics for numerical work. Use those
  standard-library modules only when their distinct scalar semantics are the
  actual requirement.
- Use pathlib paths instead of string paths and `os.path` manipulation.
- Always import the datetime module as `dt`; do not import the datetime class
  under the name `datetime`.

## Migration behavior

- Rewrite calls, types, tests, dependency metadata, and error handling when
  replacing a non-preferred library. Do not perform import-only substitutions.
- Preserve a non-preferred library when replacing it would break a required
  third-party interface. Keep it at a narrow adapter boundary and explain the
  exception in the handoff.
- Avoid adding heavyweight dependencies for code paths that do not need their
  capability. Apply preferences when the relevant capability is present.
