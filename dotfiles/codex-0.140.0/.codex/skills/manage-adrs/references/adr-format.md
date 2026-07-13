# ADR Format Reference

Use this reference when a project has no existing ADR convention or when the
local convention is incomplete.

## Default Location

Prefer `docs/adr/` for new ADR sets. Use four-digit numbering:

```text
docs/adr/
|-- README.md
|-- 0001-use-postgresql.md
`-- 0002-adopt-event-driven-ingestion.md
```

## Status Values

Use the project's existing vocabulary when present. Otherwise use:

- `Proposed`: The decision is being discussed.
- `Accepted`: The decision is approved and current.
- `Superseded`: A later ADR replaces this decision.
- `Deprecated`: The decision should no longer be followed, with no direct replacement.
- `Rejected`: The option was considered but not chosen.

Avoid status churn. Historical ADRs should usually move forward through status
notes and supersession links, not by rewriting their decision.

## Default Template

```markdown
# ADR NNNN: Title

- Status: Proposed
- Date: YYYY-MM-DD
- Deciders: TODO
- Supersedes: None
- Superseded by: None

## Context

Describe the forces, constraints, project state, and problem being decided.

## Decision

State the decision directly.

## Options Considered

List serious alternatives and the practical reason each was not chosen.

## Consequences

Describe expected benefits, tradeoffs, operational impact, migration work,
risks, and follow-up decisions.

## Notes

Add later amendments or implementation references without rewriting the historical decision.
```

## Index Template

Use `README.md` in the ADR directory when the project has no index:

```markdown
# Architecture Decision Records

| ADR                     | Title   | Status   | Date       |
| ----------------------- | ------- | -------- | ---------- |
| [0001](0001-example.md) | Example | Accepted | 2026-01-01 |
```

## Review Checklist

- Numbers are unique and sorted.
- Filenames use the same number width and slug style.
- Every ADR has a title, status, date, context, decision, and consequences.
- Superseded ADRs link to their replacement, and replacements link back.
- Proposed ADRs are not silently treated as accepted decisions.
- The index reflects the current files.
