# Native Python CLI Standard

## Contents

- Runtime and dependencies
- CLI contract
- Architecture and typing
- Errors, output, and logging
- Side effects and safety
- Inline tests
- Completion checklist

## Runtime and Dependencies

- Target personal POSIX tooling on the installed Python 3 interpreter, version
  3.11 or newer.
- Start with `#!/usr/bin/env python3` and define `MINIMUM_PYTHON = (3, 11)`. Add
  `from __future__ import annotations` immediately after the module docstring.
  Reject an older interpreter with a concise stderr diagnostic and a nonzero
  exit before business side effects.
- Set the POSIX executable bit (`chmod +x SCRIPT`) so the shebang is the public
  execution interface. Run and document the script directly.
- Use only Python standard-library modules. Do not add PEP 723 metadata,
  requirements files, lockfiles, pip or uv bootstrapping, vendored packages,
  optional third-party imports, or subprocess calls that delegate core behavior
  to third-party CLIs.
- Prefer a uv-native script when a mature dependency is required for correctness
  or when a standard-library implementation would be unsafe or disproportionate.

## CLI Contract

- Use `argparse` with required subcommands. Expose at least one visible task
  command, a visible `check` command, and a visible `unit-test` command.
- Give every command concise help, typed arguments, meaningful defaults, and
  stable option names. Use `argparse` choices and types for syntax-level input
  constraints. Validate domain rules in the functional core.
- Let `argparse` use exit code `2` for usage errors. Translate expected domain
  failures at the command boundary into a concise `Error: ...` diagnostic on
  stderr and exit code `1`.
- Keep parser construction and top-level dispatch free of business side effects
  so `--help`, `check`, and `unit-test` remain safe.
- Put normal results on stdout. Reserve stderr for logs, warnings, and errors.
- Make `check` a read-only readiness probe for everything the script needs at
  runtime: interpreter version, configuration shape, required files and
  executables, permissions, credentials, and safe connectivity or authentication
  probes where useful. Do not install, initialize, migrate, or repair setup from
  `check`.
- On readiness success, make `check` print exactly `ok` followed by a newline on
  stdout and exit zero. On failure, exit nonzero and put actionable, secret-safe
  diagnostics on stderr. Keep status logs off stdout.
- Use `unit-test` for code correctness and `check` for runtime readiness. When
  no external setup is required, validate the interpreter and real runtime
  invariants and still provide the stable `ok` contract.

## Architecture and Typing

- Separate a functional core from an imperative shell. Keep parsing, filesystem,
  network, environment, subprocess, clock, and terminal interactions at explicit
  edges.
- Fully type functions, collections, callbacks, exceptions, and data models.
  Avoid `Any`, untyped dictionaries, blanket ignores, and casts that hide design
  problems.
- Use frozen `dataclasses`, enums, `NamedTuple`, `TypedDict`, and explicit
  validation for structured data. Do not reproduce a third-party validation
  framework inside one script.
- Prefer small pure functions. Inject side-effecting callables or adapters when
  doing so makes important behavior testable.
- Avoid module-import side effects. Load configuration and initialize logging
  from the CLI execution path.
- Use `pathlib.Path`, timezone-aware datetimes, context managers, explicit
  encodings, and argument-vector subprocess calls with timeouts. Never use
  `shell=True`.
- Add a module docstring. Add docstrings or comments only for contracts, intent,
  risk, or surprising behavior.

## Errors, Output, and Logging

- Define specific domain exceptions for expected failures. Catch them only where
  recovery or CLI translation is possible.
- Do not catch `Exception` unless adding context and re-raising, performing
  best-effort cleanup, or isolating independent batch items.
- Import standard logging as `logging as lg`. Configure one module logger with a
  `StreamHandler` bound to stderr, UTC ISO-like timestamps, log level, and a
  stable event name. Put operational values in structured `key=value` fields
  rather than interpolating them into the event name.
- Never log secrets. Redact credentials from URLs and subprocess diagnostics.
- Return machine-consumable data on stdout when the command naturally produces
  data. Keep progress and diagnostics off stdout.

## Side Effects and Safety

- Make filesystem and remote mutations explicit in command names and help.
- Add `--dry-run` to every command that can make a durable local or remote
  change. Do not add it to commands that are intrinsically read-only.
- Make dry-run follow the real discovery, input loading, parsing, validation,
  authorization checks, selection, and planning path as far as possible. Stop
  before the first durable mutation and simulate later decisions when needed;
  temporary artifacts are allowed only when isolated and cleaned up.
- Make dry-run skip filesystem writes, database changes, remote mutations,
  messages, uploads, commits, pushes, and other externally visible effects. It
  may use read-only network calls and subprocesses. Clearly preview what would
  change without exposing secrets, and never prompt for mutation confirmation
  during dry-run.
- Add confirmation before destructive or broad changes and a clearly named
  non-interactive override such as `--yes`.
- Use atomic writes where partial files would be harmful. Preserve permissions
  when replacing existing files.
- Set timeouts for network and subprocess operations. Retry only transient, safe
  operations with bounded backoff; never retry non-idempotent actions blindly.
- Return a nonzero result when any requested item fails unless the command
  explicitly documents partial-success semantics.

## Inline Tests

- Keep `unittest` tests in the script below production definitions and above the
  `__main__` guard.
- Register a visible `unit-test` subcommand that builds a suite from the current
  module, runs it with `unittest.TextTestRunner`, and returns nonzero on
  failure.
- Keep test output on stdout and avoid discovery outside the script.
- Test pure logic, expected domain errors, parser help, command success,
  stdout/stderr separation, `check` success and failure, dry-run non-mutation,
  and meaningful failure paths.
- Use `tempfile`, `unittest.mock`, `contextlib.redirect_stdout`, and injected
  adapters. Never contact real services or mutate user data in tests.
- Standard-library-only scripts cannot self-provide branch coverage or static
  type analysis. Do not fake those results. Use repository-level tooling when
  independently available, but keep it outside the script's runtime contract.

## Completion Checklist

- Confirm the direct `python3` shebang, executable bit, Python 3.11
  minimum-version guard, future annotations import, absence of PEP 723 metadata,
  and absence of dependency or lock files.
- Confirm every import belongs to the standard library and follows the import
  policy.
- Confirm the visible task commands, `check`, and `unit-test` behave as
  documented; require `check` to emit exactly `ok` on stdout.
- Confirm primary output uses stdout and standard logging uses stderr.
- Confirm every mutating command has dry-run and confirmation semantics, and
  prove dry-run reaches the latest safe point without durable side effects.
- Run `scripts/validate_script.py validate SCRIPT` and inspect every result
  rather than assuming success.
