# Evaluation results

Run date: 2026-09-06. Scope: new local `adr` skill. Synthetic task probes and
subsequent migration of the 40 existing CTB ADRs.

## Executed task probes

Independent agents received the skill, task prompt, and task-local fixtures.
They did not receive the eval assertions or expected outputs.

| Case                         | Evidence                                                                               | Observed result                                                                                                                                        |
| ---------------------------- | -------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2: incomplete cache decision | `results/draft-cache/ADR-SYS-0001-cachekeuze-catalog.md`                               | DRAFT, Undecided, TODO owner/decider, null dates; latency explicitly unmeasured; genuine options and proposed measurements.                            |
| 3: approved supersession     | `results/supersession/ADR-SYS-0001-use-postgresql.md` and `ADR-SYS-0002-use-sqlite.md` | New 0002 ACCEPTED with supplied date, reciprocal references, changed deployment context and migration consequences. Old rationale and dates preserved. |

A direct file comparison against the original fixture showed only two changes to
the historical ADR: status and `superseded_by`.

Initial execution happened before the validator was complete. Validation of
these retained outputs is recorded below separately from the task probes. The
initial draft trace is in `results/draft-cache/README.md`.

## Revisions prompted by probes

The draft probe exposed ambiguous wording that assumed a chosen option. The
skill now explicitly permits Undecided and describes the evidence needed to
choose. It also explicitly allows a short statement that no neutral effect is
known, to avoid filler. These instruction changes were manually reviewed; the
task-generation probes were not repeated after that wording revision.

## Automated checks

- Skill metadata: `quick_validate.py validate …/local/adr` passed, including the
  `compatibility` field, after the checker fix described below.
- Readiness: `uv run scripts/validate_adrs.py check` printed exactly `ok`.
- Embedded suite: `uv run scripts/validate_adrs.py unit-test` passed 38 tests;
  pytest-cov reported 88% combined statement/branch coverage.
- CLI standard checks: Ruff formatting and lint, ty, and Pyrefly basic passed.
- Strict complete fixture: 1 file, 0 errors, 0 warnings, exit 0.
- Strict supersession output: 2 files, 0 errors, 0 warnings, exit 0.
- Draft output: 1 file, 0 errors, 7 warnings, exit 0. Strict mode: 7 errors, 0
  warnings, exit 1 as expected.
- Actual template content is embedded in a regression test with a conforming
  filename: default produces only warnings; strict produces errors.
- Task/trigger JSON parsed successfully: 7 unique task IDs and 10 boolean
  trigger labels.

Commands above ran from the skill directory or with its full repository path.
This environment allowed `uv run` while its command filter blocked direct
execution of the new script. No filter configuration was changed. The executable
shebang remains the normal public interface.

The retained outputs satisfy the content assertions of cases 2 and 3. Their
execution agents could not run validation at generation time; the parent ran the
real checks afterwards. Thus the artifact validation passed, while the assertion
that the execution agent itself ran and reported validation was blocked in those
original traces. These are useful forward probes, not two fully passing
end-to-end benchmark cases.

## Agent Skills specification check

Checked against the repository's `docs/agentskills.io/specification.md` on
2026-09-06. The required YAML fields and Markdown body are present; `adr`
matches the directory name and naming rules. The trigger-form description is 312
characters (limit 1024). SKILL.md is 89 lines, below the recommended 500-line
limit. Resources use relative paths from the skill root; extra agents/evals
directories are permitted. Runtime dependencies were already documented in the
body and are now also exposed in the optional `compatibility` field (130
characters; limit 500).

The official reference validator passed with exit 0:

```bash
uv tool run --from 'git+https://github.com/agentskills/agentskills@69ef37e9424c0a7ea9dd2293b559e43ec8176379#subdirectory=skills-ref' skills-ref validate dotfiles/agents/.agents/adr
```

The run resolved that exact upstream revision and reported `Valid skill`. The
local skill-creator `quick_validate.py` initially rejected `compatibility` as an
extra field. The follow-up fix now accepts its omission or nonempty strings of
1–500 characters and rejects null, wrong types, whitespace-only values, and
excessive length. Its 31 tests pass with 100% statement/branch coverage; Ruff
checks pass. Validation of this ADR skill also passes locally. That
compatibility fix did not change the ADR validator; the migration below
subsequently added one ADR-validator regression test.

## Existing CTB collection migration

All 40 legacy ADRs in `ctb/full-rewrite-v2/docs/adr` were migrated with the
user-confirmed SYS domain, CTB system, and NostraDavid as owner and decider.
Missing driver weights and alternatives were explicitly labeled retrospective,
as authorized by the user. Existing substantive fragments were checked against a
source snapshot after ADR-reference rewriting; 245 local links resolved. The
updated index includes a mapping from legacy filenames to current records.

The two Deferred records became PROPOSED with null decision dates; their
original status and dates remain documented. Partial supersession remains a
documented relationship without incorrectly superseding entire records.

The real collection exposed a false positive for inline code such as
`codex/<task>`. The validator now allows parameter notation in code spans while
still flagging explicit TODOs and prose placeholders. The regression reproduced
the failure before the fix. Afterwards, 39 tests passed with 88% combined
statement/branch coverage, and Ruff formatting and lint passed.

Strict validation passed both before and after applying the migration: 40 files,
0 errors, 0 warnings, exit 0. The target repository's `git diff --check` also
passed. Source hashes were checked before applying the conversion to prevent
overwriting intervening edits. This is a real collection check, not an
additional independent task-generation or trigger benchmark.

## Unexecuted evaluations

Task cases 1, 4, 5, 6, and 7 were authored but not executed as independent
end-to-end agent runs. The ten trigger queries were added but no routing
benchmark was run. JSON/schema inspection is not a trigger-selection score.
Implicit routing overlaps with existing ADR skills and remains unmeasured.
