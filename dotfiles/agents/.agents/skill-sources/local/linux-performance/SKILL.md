---
name: linux-performance
description: Diagnose a measured Linux host or process performance problem across CPU, scheduler, memory, filesystem, storage, network, locks, and kernel behavior. Use for unexplained latency, low throughput, saturation, stalls, load, swapping, I/O waits, packet loss, or resource regressions on Linux. Do not use for application-only profiling, SQL tuning, or generic shell-command questions.
---

# Linux Performance

Use a hypothesis-driven measurement loop. Do not tune from folklore or from one ambiguous utilization number.

## Workflow

1. Define the performance contract: workload, latency/throughput/error distribution, affected scope, baseline, start time, change history, and observation window.
2. Check integrity first: kernel/OOM/hardware errors, failed services, resource limits, clock anomalies, and whether the workload is actually comparable.
3. Apply a broad saturation/error/utilization pass across CPU/run queues, memory/reclaim/swap, storage latency/queueing, network drops/retransmits, filesystem capacity, and cgroup/container limits.
4. Attribute resource use to process, thread, cgroup, device, mount, socket, and request where possible. A busy system-wide metric does not identify the responsible workload.
5. Form competing hypotheses and select the least invasive discriminating observation: scheduler samples, counters, profiles/flame graphs, syscall tracing, block/network tracing, or BPF.
6. Correlate timelines and distinguish demand, queueing, service time, contention, cache effects, and downstream waits. Account for coordinated omission and aggregation hiding tails.
7. Change one factor in a controlled, reversible experiment. State predicted signals, observation window, stop criteria, and collateral risks.
8. Re-run the same workload and compare distributions and resource work, not a single snapshot. Check displaced cost and regressions elsewhere.
9. Report evidence, causal mechanism, correction, validation, remaining hypotheses, and monitoring to retain.

Read [measurement cautions](references/measurement-cautions.md) before using tracing, BPF, cache-dropping, or production load tests.

## Guardrails

- Load average is runnable plus uninterruptible work, not CPU percentage.
- Free memory alone does not diagnose pressure; consider available memory, reclaim, faults, swap, PSI, and workload.
- `%util`, iowait, buffer/cache, and averages are context-dependent; combine counters with latency, queueing, and attribution.
- Profilers and tracers add overhead. Start with counters, scope probes, sample, and record tool/version/permissions.
- Never drop caches, disable safety mechanisms, or run unbounded traces/load in production without explicit authorization.
