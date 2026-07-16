# Python CLI Standard

## Contents

- Runtime and dependencies
- CLI contract
- Architecture and typing
- Errors, output, and logging
- Side effects and safety
- Inline tests
- Completion checklist

## Runtime and dependencies

- Target personal POSIX tooling on Python 3.14 or newer.
- Start with `#!/usr/bin/env -S uv run --script` and a PEP 723 block containing
  `requires-python = ">=3.14"`.
- Set the POSIX executable bit (`chmod +x SCRIPT`) so the uv shebang is the
  public execution interface. Run and document the script directly; do not
  wrap normal invocations in `uv run`.
- Keep the script self-contained. Do not add a neighboring `.lock` file.
- Pin every PEP 723 dependency with `==`. Resolve current versions with `uv add
--script SCRIPT --bounds exact PACKAGE...` instead of copying versions from
  this skill.
- Always include Click, structlog, pytest, and pytest-cov. Include Pydantic when
  data has a non-trivial schema, crosses a trust boundary, or needs coercion and
  validation.
- Use another mature library when it is a clearly better fit than custom or
  standard-library code. Keep the dependency set purposeful.

## CLI contract

- Expose a Click group, at least one visible task command, and a visible command
  named `unit-test`.
- Give every command concise help, typed options and arguments, meaningful
  defaults, and stable option names.
- Use Click validation for syntax-level input constraints. Validate domain rules
  in the functional core.
- Let Click use exit code `2` for usage errors. Translate expected domain
  failures into `click.ClickException` at the command boundary, producing exit
  code `1`.
- Keep the group callback free of business side effects so `--help` and
  `unit-test` remain safe.
- Put normal results on stdout with `click.echo`. Reserve stderr for logs,
  warnings, and errors.

## Architecture and typing

- Separate a functional core from an imperative shell. Keep parsing, filesystem,
  network, environment, subprocess, clock, and terminal interactions at explicit
  edges.
- Fully type functions, collections, callbacks, exceptions, and data models.
  Avoid `Any`, untyped dictionaries, blanket ignores, and casts that hide design
  problems.
- Treat ty as the primary and authoritative type checker. Run Pyrefly afterward
  with its `basic` preset as a complementary high-confidence check. Require both
  to pass, but follow ty when their type models or suggested designs conflict.
- Prefer small pure functions. Inject side-effecting callables or adapters when
  doing so makes important behavior testable.
- Use Pydantic models for non-trivial structured data. Configure models as
  frozen when mutation is unnecessary and use enums or constrained fields for
  real invariants.
- Avoid module-import side effects. Load configuration and initialize logging
  from the CLI execution path.
- Use `pathlib.Path`, timezone-aware datetimes, context managers, explicit
  encodings, and argument-vector subprocess calls with timeouts. Never use
  `shell=True` for convenience.
- Add a module docstring. Add docstrings or comments only for contracts, intent,
  risk, or surprising behavior.

## Errors, output, and logging

- Define specific domain exceptions for expected failures. Catch them only where
  recovery or CLI translation is possible.
- Do not catch `Exception` unless adding context and re-raising, performing
  best-effort cleanup, or isolating independent batch items.
- Import top-level `structlog as sl` as the configuration namespace and import
  `structlog.stdlib as log` as the typed logger namespace. Construct each module
  logger exactly as `logger = log.get_logger(__name__)`; do not add an explicit
  annotation, use another structlog alias, or import structlog objects
  individually.
- Configure structlog to write through `PrintLoggerFactory(file=sys.stderr)`
  with ISO timestamps, log levels, and `ConsoleRenderer`. Use
  `wrapper_class=sl.make_filtering_bound_logger("debug")`, keep console
  rendering when redirected, and enable colors only for a TTY.
- Use stable event names and structured fields. Do not interpolate operational
  data into the event name.
- Never log secrets. Redact credentials from URLs and subprocess diagnostics.
- Return machine-consumable data on stdout when the command naturally produces
  data. Keep progress and diagnostics off stdout.

## Side effects and safety

- Make filesystem and remote mutations explicit in command names and help.
- Add `--dry-run` when a useful preview can be produced. Ensure dry-run follows
  the same discovery and validation path while skipping writes.
- Add confirmation before destructive or broad changes and a clearly named
  non-interactive override such as `--yes`.
- Use atomic writes where partial files would be harmful. Preserve permissions
  when replacing existing files.
- Set timeouts for network and subprocess operations. Retry only transient, safe
  operations; use bounded backoff and never retry non-idempotent actions
  blindly.
- Return a nonzero result when any requested item fails unless the command
  explicitly documents partial-success semantics.

## Inline tests

- Keep pytest tests in the script, below production definitions and above the
  `__main__` guard.
- Register a visible Click command named `unit-test` that runs pytest against
  the same file with `--cov`, `--cov-branch`, and
  `--cov-report=term-missing`. Do not impose a generic coverage threshold.
- Keep coverage output compact: suppress pytest-cov's redundant section and
  platform banners while retaining test progress, the coverage table, missing
  lines, `TOTAL`, failures, and the final pytest summary.
- Point `COVERAGE_FILE` at a temporary location during `unit-test` and remove it
  afterward; do not leave `.coverage` or report artifacts beside the script.
- Disable pytest's cache provider for `unit-test`; a standalone script must not
  create `.pytest_cache` or depend on the current directory being writable.
- Write a temporary coverage configuration with `[run] include` set to the
  resolved script path and pass it through `--cov-config`. Never let ambient
  Python paths, installed dependencies, or repository coverage configuration
  pollute the script's report.
- Set `[run] patch = subprocess` in that configuration so end-to-end CLI tests
  measure child Python processes and the real `__main__` entrypoint.
- Test pure logic, expected domain errors, Click help, command success,
  stdout/stderr separation, and meaningful failure paths.
- Use `click.testing.CliRunner`, temporary directories, monkeypatching, and
  injected adapters. Never contact real services or mutate user data in tests.
- Keep `unit-test` visible in help and ensure `SCRIPT unit-test` reports line
  and branch coverage.

## Completion checklist

- Confirm the direct uv shebang, executable bit, and Python 3.14 metadata.
- Confirm every dependency is exactly pinned and no script lockfile exists.
- Confirm the visible task commands and visible `unit-test` command behave as
  documented and report coverage without leaving artifacts.
- Confirm primary output uses stdout and structlog uses stderr.
- Confirm imports and library choices follow the import policy.
- Confirm ty passes first and Pyrefly `basic` passes afterward.
- Confirm dry-run and confirmation semantics for risky mutations.
- Run `scripts/validate_script.py check SCRIPT` and inspect every result rather
  than assuming success.
