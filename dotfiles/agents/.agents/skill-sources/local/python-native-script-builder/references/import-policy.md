# Native Import Policy

## Standard-Library Boundary

- Accept an import only when its top-level module is present in
  `sys.stdlib_module_names` or is `__future__`.
- Do not rely on an import merely because it succeeds on the current machine;
  site packages and user-installed modules are outside the native contract.
- Do not vendor third-party source, bootstrap pip or uv, or shell out to a
  third-party CLI to evade the standard-library boundary.
- Prefer `pathlib` for paths, `urllib.request` and `urllib.error` for HTTP,
  `json` or `csv` for interchange, `sqlite3` for embedded relational storage,
  `configparser` or JSON for configuration, and `dataclasses` plus explicit
  validation for structured data. Do not use `tomllib`; it is unavailable on the
  required Python 3.11 baseline.
- Use `secrets` rather than `random` for security-sensitive values. Never use
  `pickle`, `marshal`, or `shelve` with untrusted input.
- If the standard library cannot implement the requirement clearly and safely,
  stop and recommend `python-uv-script-builder` instead of recreating a mature
  package badly.

## Aliases

- Read `import-policy.json` as the canonical alias registry. JSON keeps the
  registry trivial to inspect with the standard library.
- Import a registered module using its exact alias. Use ordinary imports or
  focused `from` imports for unregistered standard-library modules.
- Do not register aliases merely to shorten an import used once. The registry
  exists for common ambiguous module names and consistency with uv-native
  scripts.
