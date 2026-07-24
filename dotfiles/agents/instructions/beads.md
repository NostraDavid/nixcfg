# Beads

Use Beads as the project task ledger when work must survive session changes,
move between coding clients, or be coordinated across agents or branches.
Beads records actionable work, status, dependencies, and ownership; use Engram
for durable decisions and discoveries.

In a repository that is already configured for Beads:

```bash
bd prime
bd ready
bd show <id>
bd update <id> --claim
bd close <id> --reason "<result>"
```

- Run `bd prime` before relying on the ledger for project context.
- Claim a task before starting it and keep its status accurate.
- Record blockers and dependencies in Beads instead of an ad-hoc Markdown task
  list when the repository already uses Beads.
- Close work only after its requested outcome and relevant checks are complete.
- Keep task state in Beads and learned knowledge in Engram; do not duplicate the
  same note in both systems.

Do not run `bd init`, `bd setup`, `bd onboard`, hook installation, server-mode
setup, or remote sync unless the user explicitly asks to configure Beads for
that repository. These commands can modify project instructions, hooks, and
repository state. Do not push or pull the Dolt database without explicit
authorization.
