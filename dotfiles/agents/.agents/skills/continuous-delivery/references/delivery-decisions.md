# Delivery decisions

## Release strategy

| Condition                              | Candidate       | Required evidence                                          |
| -------------------------------------- | --------------- | ---------------------------------------------------------- |
| Stateless, backward-compatible change  | rolling         | mixed-version tests and capacity headroom                  |
| Fast traffic switch and spare capacity | blue/green      | data/schema compatibility and switch-back test             |
| Risk should be limited by cohort       | canary          | representative cohort, comparable metrics, automatic abort |
| Code may deploy before exposure        | feature control | owner, expiry/removal plan, both-path tests                |

## Health gates

Prefer user-visible correctness, latency, error, saturation, and business invariants over “pod is running.” Compare canary to a concurrent control when traffic mix changes. Define minimum sample/observation windows and guard against low-volume false confidence.

## Failure modes

- artifact rebuilt or reconfigured differently in each environment;
- deployment declared healthy before dependencies and real workflows are exercised;
- database contraction while old binaries or delayed jobs remain;
- rollback path never tested with data written by the new release;
- flaky tests normalized instead of owned and repaired;
- security approval performed after the artifact can no longer change;
- GitOps controller granted broad cluster privileges without scoped projects and audited break-glass access.
