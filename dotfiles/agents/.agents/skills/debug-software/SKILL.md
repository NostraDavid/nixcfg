---
name: debug-software
description: Diagnose reproducible and intermittent software failures by turning observations into tested causal hypotheses. Use for crashes, wrong results, hangs, races, resource leaks, flaky failures, and regressions when the cause is unknown. Do not use when the defect is already localized and the user only asks for a fix, for broad code review, or for pure performance tuning without a failure.
---

# Debug Software

Find the cause before changing the program. Keep observations, hypotheses, experiments, and conclusions distinct.

## Workflow

1. State the failure as an observable mismatch: expected behavior, actual behavior, scope, frequency, and first known bad version.
2. Preserve evidence before restarting or mutating the system: exact error, input, timestamps, environment, version, logs, dump, trace, and resource state.
3. Make the failure reproducible. Start with the original case, then reduce it without changing the symptom. For intermittent failures, record rates and control scheduling, seeds, time, load, and external dependencies.
4. Trace backward from the failure through corrupted state to the earliest divergent state. Do not assume the frame that reports the failure caused it.
5. Write falsifiable hypotheses. For each, name the predicted observation and the smallest discriminating experiment.
6. Divide the search space at meaningful boundaries: producer/consumer, client/server, process, thread, release, data transformation, or call chain. Change one variable at a time.
7. Prefer observation to speculative edits: debugger, structured logging, assertions, traces, sanitizers, record/replay, differential runs, or binary search over history.
8. Confirm the cause by explaining all observations, making the failure disappear under the predicted condition, and making it return when safe to do so.
9. Apply the smallest root-cause correction. Add a regression test at the lowest reliable boundary and run relevant broader checks.
10. Report cause, evidence, fix, validation, remaining uncertainty, and any diagnostic instrumentation to retain or remove.

Read [investigation patterns](references/investigation-patterns.md) when the failure is intermittent, concurrent, environment-specific, or hard to reduce.

## Guardrails

- Reproduction is not proof of causation; correlation is not a mechanism.
- Do not shotgun-edit, add sleeps, swallow errors, or increase timeouts unless an experiment establishes why that addresses the cause.
- Preserve the original failing artifact and keep an experiment log.
- Compare like with like: build flags, dependencies, configuration, data, architecture, locale, clock, and load.
- Treat absence of logs as absence of evidence, not evidence that an event did not occur.
- For destructive, production, or privacy-sensitive experiments, use a safe replica or request authorization.

## Output

Give the user:

- the precise failure contract;
- evidence and eliminated hypotheses;
- the causal chain, or the leading hypotheses if not yet proven;
- the minimal fix or next discriminating experiment;
- the regression test and commands actually run;
- residual risks and confidence.
