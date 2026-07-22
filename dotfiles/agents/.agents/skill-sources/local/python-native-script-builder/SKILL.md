---
name: python-native-script-builder
description: Build or fully redesign dependency-free standalone POSIX Python CLI scripts supporting Python 3.11+ and using only the standard library, with argparse subcommands, logging, strict typing, inline unittest tests, readiness checks, safe dry-run behavior, and functional-core architecture. Use when Codex creates or redesigns a standalone Python script that must run on an installed Python interpreter without uv, PEP 723, pip, PyPI, virtual environments, or third-party imports. Use python-uv-script-builder instead when PyPI dependencies are allowed or requested. Do not use for Python packages, libraries, services, notebooks, or application repositories.
---

# Python Native Script Builder

Build one-file, standard-library-only Python CLIs that are predictable,
self-testing, and deployable as a single executable file.

## Workflow

1. Read [the native Python CLI standard](references/python-cli-standard.md),
   [the import policy](references/import-policy.md), and its canonical [alias
   registry](references/import-policy.json) completely.
2. Inspect repository instructions, the target script, nearby callers,
   documentation, and tests before changing existing code.
3. Treat an existing script as a source of requirements, not as an interface
   that must remain compatible. Preserve its intended capabilities, inputs,
   outputs, side effects, and important failure modes. Redesign its CLI and
   implementation unless the user requires compatibility.
4. Confirm that the requested behavior is feasible with the Python standard
   library. Stop and explain the missing capability instead of silently adding
   uv, pip, vendored code, or a third-party dependency.
5. Resolve missing product intent from local evidence. Ask only when a choice
   materially changes behavior and cannot be discovered.
6. Keep the result in one file. Stop and propose a package or a uv-native script
   before implementation if one dependency-free file would be materially unsafe
   or unmaintainable.
7. Scaffold new scripts with:

   ```bash
   scripts/scaffold.py create OUTPUT --command-name NAME
   ```

   The scaffold marks the generated script executable. Invoke it directly
   through its `python3` shebang. Replace the example behavior and tests rather
   than layering the requested feature around them.

8. For existing scripts, apply the same structure directly. Remove PEP 723
   metadata, third-party imports, dependency bootstrap code, and neighboring
   script lockfiles. Ensure the executable bit is set with `chmod +x SCRIPT`.
9. Verify the completed script with:

   ```bash
   scripts/validate_script.py validate SCRIPT
   ```

10. Report the redesigned commands, meaningful behavior changes, standard
    library tradeoffs, safety controls, `check` readiness result, and exact
    checks that passed.

## Working Rules

- Use only modules from Python's standard library in the resulting script. Do
  not add PyPI dependencies, uv or pip bootstrap behavior, PEP 723 metadata,
  vendored packages, or imports that merely happen to be installed locally.
- Keep secrets out of source, logs, command previews, and test fixtures.
- Preserve unrelated working-tree changes and avoid generated files outside the
  requested script.
- Keep every standalone script executable and document direct invocation as
  `./script.py ...` or an equivalent path, never `uv run`, `pipx`, or an
  activated virtual environment.
- Give every script a visible, read-only `check` command that verifies its
  required runtime setup and prints exactly `ok` on stdout when ready.
- Add `--dry-run` to every command that can make a durable local or remote
  change. Run discovery, loading, validation, and planning as far as possible,
  but cross no mutation boundary. Do not add a meaningless dry-run option to a
  read-only command.
- Add confirmation for meaningful or destructive mutations. Keep automation
  possible through an explicit non-interactive override.
- Use English for code, help, errors, logs, and documentation.
