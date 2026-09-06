# ADR format contract

## Contents

- Source and identity
- Metadata
- Lifecycle and relationships
- Body structure
- Validation boundary

## Source and identity

Use UTF-8 Markdown with one YAML mapping between opening and closing `---`
lines at the start of the file. Quote ambiguous strings and titles containing
colons. YAML booleans, numbers, and mappings are not substitutes for text.

Name files `ADR-<domain>-XXXX-<lowercase-hyphenated-slug>.md`, for example
`ADR-SYS-0001-use-postgresql.md`. The slug describes the decision; do not rename
an accepted record merely to match a minor title correction. The ID is stable
and appears in metadata and as a standalone inline-code paragraph after H1.

Numbers start at 0001 and increase within each domain. Gaps are allowed, IDs
are never reused, and SYS-0001 and OP-0001 are distinct. Stop at 9999 and agree
a format extension rather than wrapping the counter. Include all historical
statuses when allocating a number. A current directory cannot prove that an
ID was never used in deleted history.

## Metadata

| Key | Type and rule |
| --- | --- |
| id | Required string matching ADR-(OP, SYS, TRS, CM)-four digits; number greater than zero. |
| title | Required nonempty string; matches the single H1. |
| status | Required: DRAFT, PROPOSED, ACCEPTED, REJECTED, DEPRECATED, or SUPERSEDED. |
| domain | Required: OP, SYS, TRS, or CM; matches the ID. Meanings are organization-specific. |
| system | Required nonempty string or null; null for unknown or cross-system applicability. |
| owner | Required nonempty string naming the content owner; TODO allowed only as unfinished content. |
| decider | Required nonempty string naming the approver; TODO allowed only as unfinished content. |
| decision_date | Required ISO YYYY-MM-DD date or null; mandatory for ACCEPTED, DEPRECATED, SUPERSEDED. For REJECTED, use the rejection date if known. |
| last_reviewed_date | Required ISO date or null; no earlier than decision_date if both exist. |
| supersedes | Optional list of unique ADR IDs; defaults to []. |
| superseded_by | Optional list of unique ADR IDs; defaults to []. |
| related | Optional list of unique ADR IDs; defaults to []; directional, no reciprocal entry required. |

Reject unknown keys, duplicate YAML keys, invalid dates, and future dates.
YAML anchors and aliases are intentionally unsupported; write relationships
explicitly. Reject symbolic-link files rather than reading outside the selected
collection. Missing required fields and wrong types are errors, even in a draft. Preserve
null as a YAML null, not the string "null". Dates may be quoted or unquoted.

## Lifecycle and relationships

- DRAFT: work in progress; date normally null.
- PROPOSED: ready for discussion; approval still unresolved.
- ACCEPTED: approved decision; preserve the original rationale.
- REJECTED: considered and not adopted; retain rejection rationale.
- DEPRECATED: previously accepted but no longer applicable, without a required
  replacement; explain why.
- SUPERSEDED: replaced by another approved decision; retain the original
  decision date and require at least one `superseded_by` ID.

An approved replacement may point back with `supersedes`. Each old target must
be SUPERSEDED and point forward with `superseded_by`. A replacement can itself
later become SUPERSEDED or DEPRECATED; that does not invalidate the historical
link. DRAFT/PROPOSED/REJECTED records cannot act as approved replacements.
Records in other statuses must not have `superseded_by`.

All metadata references resolve within the validated collection. Reject self
references, repeated IDs, missing targets, and supersession cycles. Relations
may cross domains. If both decision dates are known, the replacement must not
predate the old decision. Do not compare numbers across domains to infer time.
Use `related` for proposed replacements and other dependencies until approved.

## Body structure

Keep exactly these H2 sections in this order:

1. Context and Problem Statement
2. Decision Outcome
3. Participants
4. Consequences
5. Decision Drivers
6. Considered Options
7. More Information

Put exactly one H1 matching `title` above them. Keep headings and table headers
in English for consistent parsing; prose may follow the requested language.

In Decision Outcome, include `**Chosen option:** <exact option name>` and
a justification. Use `Undecided` for an unresolved DRAFT/PROPOSED and explain
what must be resolved. In a REJECTED record, the named option is the rejected
proposal, not a claim that it was adopted; explain the rejection.

Under Consequences, use H3 Positive, Negative, and Neutral, each with content.
Under Decision Drivers, use the columns Driver, Relative weight, Description
with at least one filled row. Weights are High, Medium, or Low and are ordinal.

Under Considered Options, use Option and Summary columns with at least two
distinct options. Include H3 Pros and Cons of the Options, then one H4 per
option, matching the table names in order. Describe each option and why it was
selected or rejected, or what is needed to decide in an unresolved draft.
Under each H4, include H5 Pros and Cons and substantive Good, Neutral, and Bad
observations. A short statement that no effect is known is sufficient; avoid
filler or invented effects.
Keep implementation detail and evidence links in More Information if useful.

The template is deliberately unfinished. Copy it to a correctly named record,
replace the example ID/domain/title together, and resolve TODOs before approval.
Do not validate the assets directory as an ADR collection.

## Validation boundary

The validator recursively inspects Markdown files in a dedicated collection;
README.md and index.md are excluded as indexes. Empty input, parse errors,
invalid schema, structure, and relationships fail. Incomplete DRAFT/PROPOSED
content warns by default and fails with `--strict`; finalized content must
be complete. Code fences and HTML comments do not satisfy required headings
or count as prose. The script does not modify input.

The validator checks the declared profile, not arbitrary Markdown syntax or
semantic correctness. It does not fetch URLs, verify owners or approval against
an identity service, audit index contents, prove that an alternative is viable,
or inspect Git history. Review these separately. Explicit metadata IDs define
machine-checked relationships; ordinary prose links are supporting evidence.

Exit codes are 0 for a passing validation (possibly with draft warnings), 1 for
validation or input-content failures, and 2 for CLI usage errors such as a missing
path. JSON output contains files, errors, warnings, and issues; each issue has
path, code, message, and severity. Usage and discovery failures may emit a
stderr diagnostic instead of JSON. Supply the whole collection for relationship
checks; checking one file cannot resolve references to other files.
