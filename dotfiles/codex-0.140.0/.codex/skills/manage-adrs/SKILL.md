---
name: manage-adrs
description: Manage Architecture Decision Records (ADRs) in software projects. Use when Codex needs to create, update, review, supersede, deprecate, list, renumber, index, or summarize ADR files such as docs/adr/0001-title.md, architecture/decisions/*.md, or any project-specific decision log.
---

# Manage ADRs

## Overview

Use this skill to maintain an ADR set with consistent discovery, numbering, status handling, links, and index updates. Preserve local ADR conventions when they exist; otherwise use the default Markdown ADR format in `references/adr-format.md`.

## Workflow

1. Discover existing ADR conventions before editing.
   - Search for `docs/adr`, `doc/adr`, `adr`, `architecture/decisions`, `docs/architecture`, and filenames matching `[0-9][0-9][0-9][0-9]-*.md`.
   - Read the newest accepted ADR and any ADR index or README to infer directory, numbering width, title style, metadata fields, status vocabulary, and date format.
   - If no ADRs exist, create `docs/adr/` and use the default format.

2. Clarify the requested operation.
   - Create a new ADR for a decision or proposed decision.
   - Update an existing ADR without changing historical intent.
   - Supersede or deprecate an older ADR with a new decision.
   - List, summarize, validate, or regenerate an ADR index.
   - Review an ADR set for consistency and missing links.

3. Use the helper script for mechanical file operations when useful:

   ```bash
   python scripts/adr.py detect --project /path/to/project
   python scripts/adr.py new --project /path/to/project --title "Use PostgreSQL for event storage" --status Proposed
   python scripts/adr.py list --project /path/to/project
   python scripts/adr.py index --project /path/to/project
   python scripts/adr.py status --project /path/to/project --adr docs/adr/0003-old-choice.md --status Superseded --superseded-by 0007-new-choice
   ```

   If Python is unavailable, perform the same steps manually.

4. Edit ADRs as durable project history.
   - State the decision plainly.
   - Keep context and consequences specific to the project.
   - Do not rewrite accepted historical ADRs to make the present look cleaner; add amendments, status changes, or superseding ADRs.
   - Link related ADRs by number and title when one decision affects another.

5. Validate before finishing.
   - Confirm numbering is unique and monotonic.
   - Confirm filename slug matches the title closely enough to find.
   - Confirm status values are consistent with local vocabulary.
   - Regenerate or update the index when the project has one.
   - Run project tests only when ADR changes include code or documentation checks that require them.

## Creating ADRs

Read `references/adr-format.md` when creating the first ADR in a project, when local conventions are unclear, or when the user asks for ADR structure guidance.

For a new ADR:

- Use the next integer after the highest existing ADR number.
- Use a lowercase hyphen slug in the filename.
- Prefer status `Proposed` when the decision is not approved yet, and `Accepted` when the user asks to record a decided direction.
- Include `Context`, `Decision`, and `Consequences`; add `Options Considered` when tradeoffs matter.
- If the user has not provided enough decision context, draft explicit `TODO` markers only when asking would block progress.

## Updating ADRs

When changing an existing ADR:

- Preserve original decision text unless the user explicitly wants a correction.
- For status transitions, update the status line and add a short note under `Consequences` or `Notes`.
- For supersession, create a new ADR for the new decision, mark the old ADR `Superseded`, and add reciprocal links.
- For deprecation without a replacement, mark the ADR `Deprecated` and explain what changed.

## Reviewing ADR Sets

When asked to review or summarize ADRs:

- Build an inventory from filenames and headings.
- Report status distribution, stale proposed ADRs, missing supersession links, duplicate numbers, and inconsistent templates.
- Prefer concise findings with file links and concrete fixes.

## Resources

- `scripts/adr.py`: Detect ADR directories, create new ADR files, list ADRs, update status metadata, and regenerate a Markdown index.
- `references/adr-format.md`: Default ADR template, status vocabulary, and review checklist.
