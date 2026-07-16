# Reliability decisions

## SLI contract

For every SLI record: user/journey, event population, good predicate, measurement point, aggregation, window, exclusions, late/missing data behavior, and known bias. A proxy metric is acceptable only when its relationship to user experience is demonstrated.

## Retry checklist

- Is the operation safe to repeat or protected by an idempotency key?
- Which layer owns retries and the end-to-end deadline?
- Which failures are transient and which must fail fast?
- Are attempts bounded and delayed with jitter?
- Can extra attempts overload the dependency or duplicate side effects?
- Is the original failure visible after eventual success?

## Overload sequence

Observe queueing and saturation, cap concurrency/queues, apply backpressure, shed lowest-value work, degrade noncritical features, and preserve recovery headroom. Scaling can help only when the constrained resource scales and dependencies can absorb the load.

## Recovery evidence

Backups are not recovery until a restore is timed and verified. Test loss of a zone/region/dependency, stale configuration, corrupt data, expired credentials, and operator unavailability. Record actual RTO/RPO and reconciliation steps.
