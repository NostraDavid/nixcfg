---
name: database-refactor
description: Plan and implement safe evolutionary changes to an existing database schema while preserving data, compatibility, and required behavior. Use for renaming or splitting tables or columns, changing types or constraints, backfilling data, replacing legacy schema, or coordinating zero/low-downtime database migrations across application versions. Do not use for greenfield schema design or isolated query tuning.
---

# Database Refactor

Change production schemas through small, observable compatibility steps.

## Workflow

1. Inspect the current schema, migration tooling, application access paths, downstream consumers, data volume, supported database versions, deployment topology, and service-level objectives.
2. State the invariant to preserve and the design problem to remove. Do not call a behavior-changing feature a refactor.
3. Discover every coupled asset: queries, ORM mappings, views, procedures, triggers, reports, ETL, CDC, caches, tests, permissions, and operational tooling.
4. Classify the change:
   - additive and backward compatible;
   - expand-and-contract with a compatibility period;
   - online data rewrite or backfill;
   - destructive or behavior changing.
5. Read [references/change-patterns.md](references/change-patterns.md) for the matching change type.
6. Build an ordered migration plan with preconditions, deploy steps, verification gates, observability, abort criteria, and cleanup.
7. Prefer this sequence when two application versions can overlap:
   - expand the schema;
   - deploy compatible reads and writes;
   - backfill in bounded, restartable batches;
   - validate data equivalence and application behavior;
   - switch reads or ownership;
   - observe through the agreed compatibility window;
   - contract only after old consumers are gone.
8. Test on production-shaped data. Measure locks, transaction duration, WAL/log growth, replication lag, disk headroom, backfill rate, and query regressions relevant to the engine.
9. Execute against a live or shared database only with explicit user authorization. Preserve a human-controlled cutover for consequential migrations.

## Safety rules

- Treat migrations, application changes, and data movement as one coordinated change set.
- Keep migrations uniquely ordered and under version control with their tests.
- Make backfills idempotent or checkpointed, bounded, observable, and safe to resume.
- Do not assume a down migration can restore dropped or transformed data. Prefer roll-forward recovery after destructive steps.
- Do not combine a long data rewrite with unrelated DDL.
- Verify current official engine documentation for lock behavior and online/concurrent DDL syntax.
- Account for all supported application versions before dropping or renaming schema.
- Define data-quality queries that prove completeness, uniqueness, referential integrity, and semantic equivalence.

## Output contract

Return:

1. current and target state;
2. affected consumers and compatibility constraints;
3. ordered expand, migrate, validate, cut over, and contract steps;
4. per-step lock and operational risks;
5. verification queries and regression tests;
6. observability and abort thresholds;
7. rollback or roll-forward strategy;
8. remaining destructive actions requiring approval.
