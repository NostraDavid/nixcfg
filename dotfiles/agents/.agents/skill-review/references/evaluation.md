# Evaluation protocol

Keep two lanes separate:

- `../evals/trigger/train.json` and `validation.json` measure implicit
  activation. Never mention `$skill-review` in these prompts. A run counts as
  activated only when client evidence shows that the skill's `SKILL.md` was
  loaded.
- `../evals/evals.json` measures task outcomes using isolated fixtures,
  deterministic assertions, and matching `with_skill` and `without_skill`
  configurations.

## Runner

The dependency-free Vibe and Codex adapter is `../scripts/evaluate.py`. Vibe is
the default runtime; select Codex explicitly with `--runtime codex`:

```bash
./scripts/evaluate.py check --runtime vibe
./scripts/evaluate.py check --runtime codex
./scripts/evaluate.py validate
./scripts/evaluate.py plan --suite all --split all --attempts 3
./scripts/evaluate.py plan \
  --suite trigger --split train --case train-positive-production-audit
./scripts/evaluate.py run \
  --workspace /absolute/path/outside-the-skill \
  --runtime vibe --suite all --split all --attempts 3 --dry-run
./scripts/evaluate.py run \
  --workspace /absolute/path/outside-the-skill \
  --runtime codex --suite all --split all --attempts 3 --yes
./scripts/evaluate.py aggregate /absolute/path/to/iteration
```

`run` uses fresh streaming Vibe sessions or ephemeral Codex JSON sessions,
installs an isolated project-level copy of the skill, exposes only read tools,
and disables the skill for the baseline. It writes nothing until `--yes` is
supplied; `--dry-run` validates inputs and prints the number of model calls.

## Retained evidence

Each iteration retains:

```text
iteration-<UTC timestamp>/
├── plan.json
├── run-metadata.json
├── benchmark.json
├── trigger/<split>/<case>/attempt-<N>/
│   ├── events.jsonl
│   ├── final.txt
│   ├── stderr.txt
│   └── result.json
└── task/<case>/<with_skill|without_skill>/attempt-<N>/
    ├── events.jsonl
    ├── final.txt
    ├── stderr.txt
    ├── grading.json
    ├── timing.json
    └── result.json
```

Record the runtime, agent, model/version, tool set, skill revision, fixture
revision, attempt, activation decision, assertion evidence, latency, tokens,
cost, and policy violations when the client exposes them. The adapters record
duration and leave unavailable token or cost data as `null`; never invent
missing telemetry.

Use deterministic checks for activation evidence, workspace mutations, schema
validity, command status, and objective output requirements. Use a blind LLM
comparison or human review only for qualities that cannot be checked
mechanically, and retain the rubric and concrete evidence.

Tune descriptions only against the train split. Select the best revision using
the fixed validation split, then confirm it with fresh queries not used during
tuning.
