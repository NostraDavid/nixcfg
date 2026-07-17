---
name: sql-optimization
description: Diagnose and improve SQL performance using workload evidence, execution plans, schema statistics, and before/after measurements across SQL databases. Use for slow queries, expensive reports, indexing decisions, pagination bottlenecks, excessive database load, or plan regressions. Do not use for general SQL code review, greenfield schema design, or PostgreSQL-only operational tuning when postgresql-optimization is available.
---

# SQL Optimization

Optimize measured bottlenecks rather than rewriting SQL from folklore.

## Required evidence

Collect or clearly mark as missing:

- database engine and exact version;
- query with representative bound values;
- schema, constraints, indexes, and relevant statistics;
- actual execution plan when safe, otherwise an estimated plan;
- row counts, data distribution, result cardinality, concurrency, and cache state;
- baseline latency, throughput, resource use, and service objective.

Do not invent plan nodes, costs, selectivity, or expected percentage gains.

## Workflow

1. Rank candidate queries by total workload impact, not one unusually slow sample alone.
2. Verify result semantics before changing query shape.
3. Read the plan from the root and reconcile estimated versus actual rows at every important node.
4. Locate the dominant mechanism: excess rows, repeated work, poor access path, sort/hash spill, blocking, network transfer, write amplification, planning overhead, or resource saturation.
5. Change one causal factor at a time:
   - predicate or join formulation;
   - index key order, coverage, or filtering;
   - statistics or cardinality information;
   - precomputation, partitioning, or data model;
   - batching, pagination, caching, or application access pattern.
6. Re-run with equivalent parameters and conditions. Compare correctness, plan, latency distribution, reads, CPU, memory/temp use, writes, and concurrency effects.
7. Retain a change only when the measured benefit justifies write, storage, maintenance, portability, and operational costs.

## Guardrails

- SQL is declarative: textual join order and “filter early” are not portable optimizer controls.
- `EXISTS`, `IN`, joins, CTEs, window functions, temporary tables, and `UNION ALL` are alternatives with different semantics; never replace one mechanically.
- A function on an indexed column is not automatically wrong; expression or functional indexes may support it.
- Composite index order follows equality/range/order requirements and engine behavior, not a universal most-selective-first rule.
- Keyset pagination needs a unique, stable ordering and explicit tie handling.
- An unused-index report is evidence to investigate, not permission to drop an index; account for observation window, replicas, constraints, and rare critical jobs.
- Test write statements and `EXPLAIN ANALYZE` variants in a safe environment because plan collection can execute side effects.

## Output

Return the baseline, diagnosed mechanism, proposed change, correctness argument, validation command or experiment, measured result when available, tradeoffs, and rollback condition. Label unmeasured proposals as hypotheses.
