# review-git-branch evaluations

Validate the definitions from the repository root:

```sh
python3 dotfiles/agents/.agents/skill-review/scripts/evaluate.py \
  validate --skill-dir dotfiles/agents/.agents/review-git-branch
```

The full five-attempt matrix runs 20 trigger cases and 3 task cases in both
configurations:

```sh
python3 dotfiles/agents/.agents/skill-review/scripts/evaluate.py \
  run \
  --skill-dir dotfiles/agents/.agents/review-git-branch \
  --workspace /tmp/review-git-branch-evals \
  --runtime codex \
  --suite all \
  --split all \
  --attempts 5 \
  --yes
```

Task cases are run with and without the skill. Trigger cases must be evaluated
implicitly, without naming the skill in the prompt. Aggregate the retained
iteration with the same evaluator and use the release policy from the
skill-review references: five attempts per case, at least 95% validation
recall and specificity, 100% boundary accuracy, at least 90% task assertions,
no mutation or policy violations, and no regression against the baseline.

A one-attempt Codex smoke run is useful before the full matrix; it is not
production evidence and cannot satisfy the release gate on its own.
