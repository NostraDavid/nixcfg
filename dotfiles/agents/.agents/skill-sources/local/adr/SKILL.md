---
name: adr
compatibility: "The validator requires uv and Python 3.14+. First use may need network access to download the interpreter and pinned dependencies."
description: "Use when the user asks to create, revise, supersede, or validate an Architectural Decision Record (ADR), create an ADR template, or check consistency across an ADR collection. Do not trigger for general architecture advice without a decision record, implementation plans, or legal alternative dispute resolution."
---

# Architectural Decision Records

Record one architecturally significant decision per file. Explain why it made
sense given the evidence and constraints at the time. Keep the record concise;
put the outcome before detailed option analysis.

## Workflow

1. Inspect the requested location, repository instructions, existing ADRs,
   indexes, and supplied decision evidence. Preserve existing conventions unless
   the user requests this skill's format. Do not silently migrate a legacy set.
2. Establish the decision, alternatives, affected participants, owner, decider,
   domain, and approval state from available evidence. Do not invent people,
   approval, dates, measurements, or meanings for OP/SYS/TRS/CM. Ask only for
   information that blocks useful progress; otherwise write an explicit DRAFT
   with TODOs and report what remains unresolved.
3. For a new collection, default to `docs/adr/` and use
   [the Markdown template](assets/adr-template.md). Read
   [the format contract](references/format.md) before writing or validating.
   Select the domain from supplied context; ask if it cannot be determined.
   Allocate the next unused number above the largest existing number in that
   domain, including rejected and superseded records. Do not fill gaps or
   renumber history. Check again immediately before writing.
4. For a decided direction, state the chosen option and its justification;
   explain why alternatives lost. For an unresolved draft, keep the outcome
   Undecided and explain what evidence is needed to choose. Compare at least
   two genuine options, including the status quo when viable, against the
   drivers. Record positive, negative, and neutral consequences; a short
   statement that no effect is known is sufficient. Never manufacture an
   alternative or consequence merely to fill a cell.
5. Keep new, unresolved decisions DRAFT or PROPOSED. Use ACCEPTED only when
   approval or an already-made decision is evidenced in the request or sources.
   An instruction to record an approved decision is sufficient; do not ask for
   the same approval again. Keep unknown dates null and report validation gaps.
6. When replacing a decision, preserve the old rationale, create a new record,
   and add reciprocal `supersedes` / `superseded_by` IDs. Only mark the old
   record SUPERSEDED when the replacement is approved. Put a proposed
   replacement in `related` until then. For deprecation without a replacement,
   use DEPRECATED and explain why. Update an existing index to match.
7. Validate the whole dedicated ADR directory, then review substance manually.
   Fix mechanical defects within the requested scope. Report historical or
   semantic inconsistencies without silently rewriting accepted decisions.

## Validation

The executable uses `uv`, Python 3.14+, and pinned YAML/Markdown parsers;
Python's standard library has no full YAML parser. The first invocation may
download the interpreter and dependencies.
Run from the skill directory (or resolve the script's absolute path):

```bash
./scripts/validate_adrs.py check
./scripts/validate_adrs.py validate /path/to/project/docs/adr
./scripts/validate_adrs.py validate /path/to/project/docs/adr --strict --format json
./scripts/validate_adrs.py unit-test
```

The validator is read-only. Default mode allows unfinished DRAFT/PROPOSED content
with warnings; `--strict` makes completeness warnings fail too. Schema,
structure, and relationship errors fail in either mode. Validate this format
only: a legacy-format failure does not prove that its architecture is wrong.
Use the repository's existing checks for other formats.

Report files produced or changed, status, unresolved content, validation
command and result, and material limits. A structural pass does not establish
approval, factual accuracy, sound trade-offs, or compatibility between decisions.
Check those against the supplied evidence. Do not claim that timestamps, number
reuse, or historical immutability were verified without inspecting version history.

## Resources

- [Format contract](references/format.md): metadata, lifecycle, numbering,
  structure, validator scope, and examples.
- [Template](assets/adr-template.md): canonical Markdown source; replace TODOs
  and sample identity before use.
- [Sources](references/sources.md): origin and rationale for the format.
- [Task evals](evals/evals.json), [trigger evals](evals/trigger/validation.json),
  and [evaluation procedure](evals/procedure.md): exercise the skill beyond
  parser unit tests.

Use Markdown as the canonical editable artifact. Produce HTML only when a
reader or publishing workflow needs it, derived through the project's existing
Markdown renderer. Do not maintain an independent HTML template that can drift.
