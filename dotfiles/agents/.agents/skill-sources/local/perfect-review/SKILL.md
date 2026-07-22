---
name: perfect-review
description: Perform a prioritized, evidence-backed code review with the PERFECT framework across Purpose, Edge Cases, Reliability, Form, Evidence, Clarity, and Taste. Use when the user explicitly invokes perfect-review or asks for a PERFECT review of code, a snippet, diff, pull request, merge request, branch, or work in progress; for a structured self-review; or for team review conventions based on PERFECT. Prefer the separate code-review skill for a generic branch review against a user-supplied fixed point when PERFECT was not requested.
---

# PERFECT Review

Review code from intended behavior down to subjective preferences. Finish the
whole review in one pass, but spend attention in this order so minor style does
not obscure consequential defects.

## Establish Scope and Evidence

1. Identify the artifact under review and the change boundary. For a diff,
   report defects introduced or exposed by the change; mention unrelated
   pre-existing defects only when they materially affect the change.
2. Establish the intended behavior from the request, issue, PR description,
   specification, commit messages, or user explanation. If intent remains
   unclear, mark Purpose as `unknown` instead of inventing requirements.
3. Inspect relevant surrounding code, tests, configuration, migrations,
   interfaces, and repository instructions. Do not judge an isolated hunk when
   its behavior depends on context outside the diff.
4. Run safe, relevant automated checks when their results materially strengthen
   the review. Record the exact checks run. Never imply that tests, CI, builds,
   or linters passed when their results were not observed.
5. Keep the review read-only unless the user separately asks for fixes.

## Review in PERFECT Order

### P — Purpose

- Verify that the change solves the stated problem and produces the required
  observable behavior.
- Identify missing requirements, partial implementations, behavior that
  contradicts the specification, and unjustified scope expansion.
- Treat an unverifiable purpose as missing evidence, not automatically as a
  defect.

### E — Edge Cases

- Check relevant normal, boundary, empty, zero, null, invalid, duplicate,
  ordering, size-limit, locale, timezone, encoding, and compatibility cases.
- Examine state transitions, partial failure, retries, concurrency, and repeated
  execution when the change has those surfaces.
- Challenge "impossible" states that are safe only because of an undocumented
  assumption. Prefer explicit invariants or handling over optimism.
- Select cases from the actual domain and change; do not paste a universal
  checklist into every review.

### R — Reliability

- Look for plausible failures involving security, privacy, performance, data
  integrity, availability, and external integrations.
- Check validation and authorization boundaries, secret handling, injection
  paths, resource and algorithmic bounds, error propagation, cleanup,
  idempotency, timeouts, retries, backpressure, cache consistency, and rollback
  where applicable.
- State the concrete failure scenario and affected boundary. Do not inflate a
  generic hardening idea into a finding without evidence.
- Recommend a dedicated security or performance review when the risk surface is
  material and the available evidence cannot support a sufficiently deep pass.

### F — Form

- Evaluate whether the design fits repository conventions and keeps related
  behavior cohesive while limiting coupling.
- Flag abstractions, duplication, complexity, or dependency direction only when
  they create a concrete maintenance, correctness, or change-cost consequence.
- Let documented project decisions override generic design heuristics.

### E — Evidence

- Verify that available tests and checks cover the changed behavior and pass.
- Review tests as code: confirm that their assertions can distinguish correct
  behavior from plausible but wrong behavior, including important failures and
  boundaries.
- Flag production branches or interfaces that exist only to make tests pass
  when a natural test boundary or dependency seam would preserve real behavior.
- Identify missing evidence separately from demonstrated defects. Recommend the
  smallest test or check that would resolve a consequential uncertainty.
- Treat permanently ignored or unreliable checks as an evidence-quality issue;
  do not count their existence as coverage.
- When a check fails, report the observed failure and require review of the
  resulting fix; do not approve based on a diff that the fix will invalidate.

### C — Clarity

- Check whether names, control flow, module boundaries, comments, and public
  interfaces communicate intent without requiring unnecessary reconstruction.
- Ground clarity findings in documented conventions or a concrete risk of
  misunderstanding. Defer to the author when alternatives are merely different.
- Prefer removing accidental complexity over adding comments that restate code.

### T — Taste

- Omit personal preferences unless they offer useful optional guidance.
- Label retained taste comments as `nit` or `optional`; never make them merge
  blockers.
- Propose recurring preferences as team conventions instead of repeatedly
  debating them in individual reviews.

## Calibrate Findings

- Base priority on demonstrated impact and likelihood, not on the PERFECT
  letter. Form or Clarity can be serious when they conceal unsafe behavior;
  Taste remains non-blocking.
- Report a finding only when the change contains evidence for it and the author
  can take a concrete action. Avoid praise, vague disapproval, and speculative
  lists of everything that might go wrong.
- For every finding, provide priority, PERFECT dimension, file and line when
  available, evidence, consequence, and the smallest credible remediation.
- Distinguish confidence from impact. State what evidence would confirm an
  uncertain but material concern.
- Prefer a few high-signal findings over exhaustive low-value commentary.

## Report

Use the user's language and lead with findings ordered by priority. Do not force
seven long sections when most dimensions have nothing to report.

1. **Findings** — actionable defects and suggestions, highest priority first.
2. **Coverage** — a compact P/E/R/F/E/C/T matrix with `pass`, `finding`,
   `unknown`, or `not applicable`, plus decisive evidence or limitation.
3. **Verification** — checks actually run and their observed outcomes.
4. **Residual risk** — only material uncertainties or missing evidence.

If there are no actionable findings, say so explicitly; still report unknowns
and verification limits. Do not substitute an unexplained `LGTM` for a review.

## Self-Review and Convention Modes

For self-review, apply the same workflow before peer review and resolve obvious
findings rather than merely listing them.

For team conventions:

1. Translate every PERFECT dimension into project-specific, actionable rules.
2. Automate deterministic rules such as formatting, linting, type checks,
   dependency checks, and repeatable security scans.
3. Define reviewer ownership and number, response expectations, status
   visibility, comment resolution, re-review, and approval rules.
4. Turn recurring comment-discussion-fix patterns into written conventions and
   retire rules that no longer create value.
5. Keep self-review and meaningful approval part of the workflow.

PERFECT is adapted from Daniil Bastrich's
[The PERFECT Code Review](https://bastrich.tech/perfect-code-review/). This
skill restates and extends the framework as an operational review workflow.
