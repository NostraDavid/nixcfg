# Investigation patterns

## Reduction

Reduce one dimension at a time: input, component graph, concurrency, configuration, environment, or history. After every reduction, verify that the same failure mechanism remains. A smaller but different failure is not a useful reproducer.

## Causal chain

Distinguish:

- **failure:** externally observable deviation;
- **infection:** incorrect internal state that can propagate;
- **defect:** code, data, configuration, or operational condition that created the infection.

Walk backward from failure to the first bad state. Add assertions or probes at boundaries to locate where correct state becomes incorrect.

## Intermittent failures

- Capture a machine-readable event timeline and stable correlation identifiers.
- Record seeds, scheduling, clock, resource pressure, retries, and dependency responses.
- Run repeated controlled trials and report counts, not “seems fixed.”
- For races, prefer race detectors, deterministic schedulers, barriers, and happens-before reasoning to arbitrary sleeps.
- For leaks, compare retained objects, descriptors, threads, or allocations over a bounded workload and quiescent period.

## Differential diagnosis

Compare a good and bad run across one boundary at a time:

- input or persisted state;
- binary, commit, compiler, or flags;
- dependency and protocol version;
- configuration, permissions, or feature flags;
- host, architecture, kernel, locale, timezone, or clock;
- concurrency and load.

Use history bisection only after a deterministic oracle exists. A flaky oracle can falsely identify a change.

## Experiment log

For each experiment record: hypothesis, controlled variables, change, predicted result, observed result, and conclusion. “No conclusion” is valid; rewriting the hypothesis after observing the result is not.
