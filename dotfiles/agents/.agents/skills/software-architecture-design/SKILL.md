---
name: software-architecture-design
description: Design or evaluate software architecture from domain boundaries, quality-attribute scenarios, data and consistency needs, deployment constraints, and trade-offs. Use for selecting system structure, service/module boundaries, integration styles, evolutionary architecture, or architecture alternatives. Do not use for low-level class refactoring, relational schema design, or merely documenting an existing codebase.
---

# Software Architecture Design

Choose the smallest structure that satisfies explicit drivers and can evolve under known uncertainty.

## Workflow

1. Establish mission, stakeholders, scope, context, existing constraints, expected evolution, and irreversible decisions. Separate facts, assumptions, and open questions.
2. Express quality attributes as scenarios: stimulus, source, environment, affected artifact, measurable response, and response measure. Avoid vague “scalable,” “secure,” or “maintainable.”
3. Model domain capabilities, invariants, ownership, data lifecycle, external systems, and trust/failure boundaries before naming technologies.
4. Identify architecturally significant requirements and rank them by business impact, uncertainty, and cost of later change.
5. Generate at least two credible alternatives, including a simpler baseline. For each, trace how components, data, calls/events, deployment units, and operators satisfy the scenarios.
6. Analyze trade-offs: coupling/cohesion, consistency/availability, latency/throughput, failure isolation, operability, security/privacy, deployability, team ownership, and migration cost.
7. Select only evidence-based patterns. A pattern is a conditional solution with liabilities, not a goal.
8. Validate risky assumptions with models, prototypes, load/failure experiments, threat models, or operational rehearsal before committing.
9. Define an incremental transition with compatibility, observability, rollback/forward recovery, and criteria for revisiting the decision.
10. Record the decision and rejected alternatives in the repository's ADR convention.

Read [architecture evaluation](references/architecture-evaluation.md) for scenario and trade-off prompts.

## Guardrails

- Do not equate services with domain boundaries or deployability with distribution.
- Avoid shared databases, event buses, caches, CQRS, event sourcing, microservices, or serverless by default; justify each from drivers.
- Make data ownership and cross-boundary invariants explicit. Eventual consistency is a business semantic, not a generic scalability fix.
- Include migration and operational ownership in the design cost.
