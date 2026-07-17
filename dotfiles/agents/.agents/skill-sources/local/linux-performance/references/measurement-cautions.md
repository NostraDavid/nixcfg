# Measurement cautions

## Resource questions

For each resource ask: what work is requested, how much is completed, how long service takes, how much waits, what errors occur, and which consumer causes it. Utilization near a limit may be healthy or harmful depending on queueing and SLOs.

## Tool progression

1. Existing service and kernel telemetry.
2. Bounded process/resource counters.
3. Sampling profiles and per-thread attribution.
4. Narrow event tracing or BPF with filters and duration limits.
5. Controlled reproduction on a representative non-production system.

Validate field semantics against the installed kernel/tool documentation; counter meaning and availability change.

## Common measurement errors

- comparing different traffic, warmup, cache, power, or container-limit states;
- averaging away tail latency or burst saturation;
- blaming the component where waiting is observed rather than the downstream cause;
- interpreting sampled stacks as exact event counts;
- tracing all events and causing the problem being measured;
- changing sysctls before establishing the bottleneck;
- claiming improvement while total work, errors, or queueing moved elsewhere.
