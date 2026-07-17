---
name: reliability-engineering
description: Define, assess, or improve service reliability through user-centered SLOs, observability, capacity, resilience, overload control, incident learning, and recovery. Use for SLI/SLO and error-budget design, alerting, dependency failure, saturation, canaries, graceful degradation, disaster recovery, and reliability reviews. Do not use for a live root-cause investigation or host-level Linux performance diagnosis.
---

# Reliability Engineering

Turn reliability from an aspiration into explicit service behavior, evidence, and controlled failure handling.

## Workflow

1. Identify users, critical journeys, failure domains, dependencies, data/state, and consequences of unavailability, corruption, delay, or staleness.
2. Define SLIs at the user-observable boundary. Specify valid events, good events, exclusions, aggregation, data source, and missing-telemetry behavior.
3. Set SLOs from product need, dependency capability, current baseline, and cost. Define window and error-budget policy; do not copy “nines.”
4. Map telemetry to questions: request outcomes, traces across boundaries, relevant state changes, saturation, queues, and dependency behavior. Preserve cardinality, privacy, and cost constraints.
5. Alert on actionable symptoms and meaningful budget burn. Route to an owner and attach a tested response; dashboards without decisions are not controls.
6. Analyze capacity and overload: arrival rate, service time, concurrency, queue bounds, bottlenecks, retry amplification, backpressure, load shedding, and graceful degradation.
7. Design resilience per failure mode: timeout budgets, idempotency, bounded retries with jitter, circuit/isolation boundaries, redundancy, and explicit consistency trade-offs.
8. Define recovery objectives and prove backup restoration, failover, configuration recovery, and dependency-loss behavior through exercises.
9. Use canaries and controlled experiments with abort criteria. After incidents, repair system conditions and feedback loops, not individual blame.
10. Prioritize work by expected risk reduction, user impact, evidence strength, implementation risk, and operational cost.

Read [reliability decisions](references/reliability-decisions.md) for SLO, retry, overload, and recovery checks.

## Guardrails

- Observability is the ability to answer new questions from system outputs, not a fixed tool stack or a volume of logs.
- Redundancy without independent failure domains and tested failover may add complexity without availability.
- Retries consume capacity and can amplify an outage; assign retry budgets across layers.
- Do not silence alerts, cancel maintenance, or raise limits without evidence about the resource and failure mechanism.
