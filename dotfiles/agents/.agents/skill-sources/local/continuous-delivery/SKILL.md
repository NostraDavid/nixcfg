---
name: continuous-delivery
description: Design or improve a build, test, artifact, deployment, and release workflow so every change is releasable through repeatable automation. Use for deployment pipelines, release strategies, GitOps delivery flow, environment promotion, rollback, database-change coordination, and delivery metrics. Do not use for operating an incident, generic CI configuration, or designing application architecture.
---

# Continuous Delivery

Design a verifiable path from version-controlled change to a safely releasable production state.

## Workflow

1. Map the current value stream from commit to verified production outcome, including queues, approvals, manual handoffs, failure/rework loops, and lead time.
2. State release invariants: traceable source, reproducible build, immutable artifact, environment-independent promotion, least privilege, separation of duties where required, and observable rollback or forward recovery.
3. Define one pipeline with fast feedback first: static checks and focused tests, integration/contract/security checks, artifact attestation, deploy verification, and slower confidence checks. Fail on evidence, not flaky noise.
4. Build once and promote the same immutable artifact. Keep desired configuration and migrations versioned; keep secrets out of source and artifacts.
5. Separate deployment from release when risk warrants it. Choose rolling, blue/green, canary, or feature control from compatibility, capacity, state, and failure-containment needs—not fashion.
6. Make application, API, event, and database changes backward/forward compatible across the real coexistence window. Contract only after consumer evidence is empty.
7. Define automated health gates from user-visible outcomes plus technical signals, with explicit observation windows and stop/rollback criteria.
8. Rehearse failure: partial deploy, stale instance, failed migration, dependency outage, credential failure, and rollback after new writes.
9. Measure deployment frequency, change lead time, change failure rate, and recovery time in context; use them to find constraints, never as individual targets.
10. Deliver the staged design, ownership, approval gates, validation, recovery plan, and first small improvement.

Read [pipeline and release decisions](references/delivery-decisions.md) for strategy selection and dangerous shortcuts.

## Guardrails

- Do not automate an unsafe or misunderstood manual process without first defining its invariants.
- Never rebuild per environment, mutate a promoted artifact, or infer success from process exit alone.
- Avoid long-lived branches, environment drift, shared mutable deployment state, and manual production-only steps.
- A rollback is not safe when schema, events, or data written by the new version are incompatible with the old one; design forward recovery where needed.
