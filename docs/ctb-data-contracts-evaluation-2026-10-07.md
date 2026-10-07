# CTB data-contract skill evaluation

The CTB skill passed the declared gates for Codex CLI 0.160.0 with
`gpt-6.1-sol`, medium reasoning. Verdict: **conditionally ready for the measured
runtime and scenarios**. The results show a small generation benefit, not broad
superiority over the agent without the skill.

## Results

110 fresh model sessions ran on 2026-10-07. Each activation case had five
attempts; each task had five attempts with and five without the skill.

| Measurement                             | With skill   | Without skill  |
| --------------------------------------- | ------------ | -------------- |
| Positive activation                     | 40/40        | Not applicable |
| Negative activation, correctly inactive | 40/40        | Not applicable |
| Task success                            | 15/15        | 14/15          |
| Median task duration                    | 51.0 seconds | 54.3 seconds   |
| Total task input tokens                 | 1,796,841    | 1,970,492      |
| Total task output tokens                | 23,074       | 26,380         |

| Task                                               | With skill | Without skill | Median duration, with / without |
| -------------------------------------------------- | ---------- | ------------- | ------------------------------- |
| Generate ODCS/ODPS drafts                          | 5/5        | 4/5           | 61.0 / 74.0 seconds             |
| Review an incompatible contract change             | 5/5        | 5/5           | 45.4 / 37.7 seconds             |
| Identify an environment importing another checkout | 5/5        | 5/5           | 48.3 / 54.3 seconds             |

The unsuccessful baseline generation omitted explicit non-nullability for
`quality` and `freshness`; ODCS defaults `required` to false. Ownership,
standard conformance, decimals, timestamps, and composite keys were otherwise
present. The skill-generated descriptors preserved the required outcome fields.

There were no execution failures or detected protected-input changes. An audit
of 483 completed shell commands and web/MCP/collaboration event types found no
flagged service, installation, synchronization, or nested-model actions.

All runs together reported 8,413,886 input tokens, including 7,088,384 cached
input tokens, and 106,861 output tokens. Actual billing cost was unavailable.
Token counts are provider-reported usage, not a dollar-cost estimate.

## Method and grader correction

The fixed suite contains eight positive and eight negative activation prompts
and three task prompts. Activation required successful file-read evidence of the
target skill body. Task assertions inspected actual output descriptors or JSON
reviews. Every protected fixture file was hashed before and after its run.

Both arms used the same configured model, pinned schema files, synthetic CTB
sources, existing Python dependencies, and task prompts. The with-skill arm had
the skill package available; the baseline did not. Other installed skills and
user project instructions were disabled. Sessions were ephemeral and isolated;
only task output directories were writable by policy.

The initial owner assertion was too narrow: it accepted `team.name` but rejected
equally explicit ownership in the valid `customProperties.owner` form. Raw
records initially counted both such baseline outputs as failures. The corrected
grader accepts either representation. All 30 task artifacts were regraded and
the complete scalar type/nullability criterion was audited. One baseline
generation still failed due to missing outcome-field non-nullability.

The original records and evaluator were preserved. No prompts, model results,
skill instructions, or acceptance thresholds were changed to improve the scores.
The managed `analysis.json` records corrected scores and this adjudication.

## Limits and next use

These are synthetic CTB fixtures with string stand-ins for Polars dtypes, not
production datasets. Separate earlier script checks used the real CTB checkout;
this model evaluation does not replace production validation or consumer review.
Other agent clients and models remain unmeasured.

The small task set supports an exploratory result. Case and arm scheduling was
sequential, with three concurrent sessions. Duration and token differences are
descriptive; this experiment does not establish a causal performance advantage.
The compatibility review was faster without the skill. Retain the repeatable CLI
and CTB policy guidance, and avoid presenting the skill as a general quality
improvement based on one differing task outcome.

## Evidence and reproduction

- [Fixed cases and acceptance criteria](../dotfiles/agents/.agents/ctb-data-contracts/evals/cases.json)
- [Evaluator](../dotfiles/agents/.agents/ctb-data-contracts/evals/evaluate.py)
- [Managed analysis](../dotfiles/agents/.agents/ctb-data-contracts/evals/results/2026-10-07/analysis.json)
- [Raw events, fixtures, original grades and adjudication](/home/david/.local/state/agent-evals/ctb-data-contracts/2026-10-07/evidence.tar.gz)

Use the skill's
[evaluation procedure](../dotfiles/agents/.agents/ctb-data-contracts/references/evaluation.md)
to prepare a fresh workspace. The archived plan identifies the exact evaluated
source hashes and model settings. Use `regrade` to reassess saved artifacts
while preserving original run records.
