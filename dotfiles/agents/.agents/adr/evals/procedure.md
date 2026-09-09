# Evaluation procedure

Keep script correctness, skill task quality, and trigger selection separate.
Passing unit tests is not evidence that the skill will select or write well.

## Deterministic checks

From the skill directory:

```bash
./scripts/validate_adrs.py check
./scripts/validate_adrs.py unit-test
./scripts/validate_adrs.py validate evals/fixtures/valid --strict --format json
```

Expect zero exits; readiness prints exactly `ok`. The complete fixture is
synthetic and must pass strict checks. The legacy fixture intentionally uses
another convention and must not be silently migrated to make this validator
pass. Inline unit tests exercise malformed input, collection invariants, and CLI
failure behavior in isolated temporary directories.

## Task quality

For each case in `evals.json`:

1. Create an isolated workspace and copy its listed fixture files into
   `docs/adr/`, retaining their basenames. Start without ADRs when none are
   listed. For case 7, supply a real project with an existing Markdown pipeline
   and record its revision; otherwise mark the case blocked, not passed.
2. Give the execution agent only the prompt, workspace, and skill resources. Do
   not expose `expected_output`, assertions, previous diagnoses, or fixes.
3. Retain the produced files, command exits, relevant tool trace, and final
   response. Compare fixture before/after when history must be preserved.
4. Independently score every assertion as pass, fail, or blocked, citing an
   artifact or trace excerpt. Require all assertions to pass per case.
5. Report missing evidence as untested. Re-run affected cases after changes;
   distinguish pre-fix evidence from the final run.

Use case 2 to test useful progress with incomplete information, case 3 for
supersession, and case 5 for respecting repository conventions. No real approval
or organization is represented by the fixtures.

## Trigger selection

Use `trigger/validation.json` as held-out-style queries. Show only the skill
name and description alongside competing installed skill descriptions and the
query. Do not supply the skill body or expected label. Record actual selections,
false positives, false negatives, and whether explicit invocation was involved.

The existing create-architectural-decision-record and manage-adrs skills overlap
with this skill. Evaluate routing in the actual installed catalog before
claiming reliable implicit selection; do not alter those skills as part of this
package.

## Saved evidence

Record actual run scope and limits in `results.md`. Keep representative task
outputs under `results/`. Do not describe a manual metadata inspection as a
measured trigger evaluation or imply that unexecuted task cases passed.
