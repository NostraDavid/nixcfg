# Release policy

Repository maintainers own release decisions for this skill. A runtime is
supported only when its agent, model/version, tool set, and skill revision are
declared in retained evaluation results.

## Gates

Require all of the following before marking the skill `conditionally ready`:

- the target-platform validator and, when available, `skills-ref validate`
  both pass or their schema difference is explicitly accepted;
- every trigger and task-quality case has at least five attempts;
- validation-split positive activation recall is at least 95%;
- validation-split negative activation specificity is at least 95%;
- known boundary-case accuracy is 100%;
- with-skill task assertion pass rate is at least 90%;
- with-skill task success is not lower than the without-skill baseline;
- there are zero unauthorized mutations and safety-policy violations;
- all failed assertions have retained evidence and an explicit disposition.

Mark the skill `ready` only after those gates pass for every declared supported
runtime and an owner accepts the remaining risks. Any gate failure blocks a new
release.

Re-run trigger evals after activation metadata changes. Re-run task-quality
evals after behavioral instructions, fixtures, target agents/models, or tool
policy change. Preserve the last passing raw results and benchmark for
comparison.

Roll back to the last passing revision when a released change causes a gate
failure or safety violation. Retire a capability skill when repeated controlled
ablations show no incremental value; retain its evaluations as base-model
regression tests.
