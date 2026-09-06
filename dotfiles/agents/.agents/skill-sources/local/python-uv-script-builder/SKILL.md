---
name: python-uv-script-builder
description: "Use when creating or fully redesigning a standalone Python project script, such as repository automation, maintenance, data-processing, or developer tooling, using uv and PEP 723. This skill applies only to project scripts. Do not trigger for scripts bundled with AI-agent skills; use python-native-script-builder for those. Do not trigger for packages, libraries, services, notebooks, small maintenance edits, or scripts explicitly required to run without uv."
---

# Python uv Script Builder

Build one-file Python CLIs that are predictable, self-testing, and pleasant to
use.

## Workflow

1. Read [the Python CLI standard](references/python-cli-standard.md),
   [the import policy](references/import-policy.md), and its canonical
   [alias registry](references/import-policy.toml) completely.
2. Inspect repository instructions, the target script, nearby callers,
   documentation, and tests before changing existing code.
3. Treat an existing script as a source of requirements, not as an interface
   that must remain compatible. Preserve its intended capabilities, inputs,
   outputs, side effects, and important failure modes. Redesign its CLI and
   implementation unless the user requires compatibility.
4. Resolve missing product intent from local evidence. Ask only when a choice
   materially changes behavior and cannot be discovered.
5. Keep the result in one file. Stop and propose a package layout before
   implementation if one file would make the result materially unsafe or
   unmaintainable.
6. Scaffold new scripts with:

   ```bash
   scripts/scaffold.py create OUTPUT --command-name NAME [--with-pydantic]
   ```

   Use `--with-pydantic` for non-trivial structured input or external data. The
   scaffold marks the generated script executable; invoke it directly through
   its uv shebang instead of wrapping it in `uv run`. Replace the example
   behavior and tests rather than layering the requested feature around them.

7. For existing scripts, apply the same structure directly. Refresh all runtime
   pins during a full redesign with `uv add --script SCRIPT --bounds exact ...`.
   Do not create or retain a script lockfile. Ensure the executable bit is set
   with `chmod +x SCRIPT`.
8. Verify the completed script with:

   ```bash
   scripts/validate_script.py validate SCRIPT
   ```

9. Report the redesigned commands, meaningful behavior changes, safety controls,
   `check` readiness result, and the exact checks that passed.

## Working rules

- Consult current official documentation before selecting or using a third-party
  API that may have changed.
- Prefer a mature task-specific dependency when it materially improves
  reliability or clarity; pin every runtime dependency exactly.
- Keep secrets out of source, logs, command previews, and test fixtures.
- Preserve unrelated working-tree changes and avoid generated files outside the
  requested script.
- Keep every standalone script executable and document direct invocation as
  `./script.py ...` or an equivalent path, never `uv run script.py ...`.
- Give every script a visible, read-only `check` command that verifies its
  required runtime setup and prints exactly `ok` on stdout when ready.
- Add `--dry-run` to every command that can make a durable local or remote
  change. Run discovery, loading, validation, and planning as far as possible,
  but cross no mutation boundary. Do not add a meaningless dry-run option to a
  read-only command.
- Add confirmation for meaningful or destructive mutations. Keep automation
  possible through an explicit non-interactive override.
- Use English for code, help, errors, logs, and documentation.
