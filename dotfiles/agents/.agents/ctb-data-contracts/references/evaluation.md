# Measure skill behavior

`evals/cases.json` fixes the prompts and acceptance criteria before measurement.
It contains eight positive and eight negative activation cases and three task
cases. Five attempts per case/configuration produce 80 activation runs and 30
task runs with/without the skill.

The tasks use synthetic CTB checkouts, public pinned schemas, and an existing
Python environment. Generation is graded against independent field/type
assertions; review tasks are graded against explicit JSON outcomes. All inputs
are hashed before and after runs. Only `output/` may change.

```bash
evals/evaluate.py prepare --workspace /tmp/ctb-skill-evaluation
evals/evaluate.py run --workspace /tmp/ctb-skill-evaluation --yes
evals/evaluate.py summarize --workspace /tmp/ctb-skill-evaluation
evals/evaluate.py regrade --workspace /tmp/ctb-skill-evaluation
```

Model runs use Codex's existing account and configured model, with user config
otherwise ignored. They send the selected skill and synthetic fixture contents
to OpenAI. `--yes` confirms these external evaluation calls. Use `--case` and
`--attempts` for a pilot before the complete suite. A completed pilot can be
resumed in the same workspace; changing the skill requires a fresh plan.

Fresh ephemeral sessions run with the target skill enabled or absent. Other
installed skills are disabled. Task sessions can write within their temporary
workspace; activation sessions are read-only. No MCP servers are configured.
Successful tool output containing the target `SKILL.md` body is activation
evidence; merely mentioning the skill is not.

Each run retains events, errors, grading, duration, token usage when provided,
and input-mutation checks. `summary.json` reports per-case pass counts and
median duration. Dollar costs remain unknown unless actual billing is available.
Execution failures count as failed runs and are reported separately.

`regrade` checks saved task artifacts with the current assertions and writes a
separate adjudication file. It preserves the original events and grades.

Release requires the fixed activation and task-success thresholds, task success
not below the baseline, and zero protected input mutations. A successful script
self-test does not replace these model measurements.
