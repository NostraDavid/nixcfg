---
name: postgresql-optimization
description: Diagnose PostgreSQL performance and operational bottlenecks using EXPLAIN, pg_stat views, pg_stat_statements, wait events, vacuum and bloat evidence, WAL, replication, memory, and measured workload behavior. Use for PostgreSQL-specific slow queries, server load, indexing, autovacuum, contention, connection, or replication problems. Do not use for generic SQL review or unmeasured feature recommendations.
---

# PostgreSQL Optimization

Use `sql-optimization` for the evidence loop, then apply PostgreSQL-specific diagnostics.

## Safety first

- Confirm the exact PostgreSQL version and whether the target is production, a replica, or a disposable environment.
- Remember that `EXPLAIN ANALYZE` executes the statement. Wrap data-changing experiments in `BEGIN`/`ROLLBACK` only when all effects are transactional and safe; otherwise use a clone.
- Avoid clearing statistics, caches, or shared state unless the user explicitly authorizes it.
- Treat configuration and DDL changes as hypotheses with rollback criteria.

## Diagnose by symptom

### Workload

Use `pg_stat_statements` when enabled. Rank by `total_exec_time`, calls, mean and tail behavior available from surrounding monitoring, rows, block reads, temp I/O, and WAL rather than relying on obsolete column names or a single metric. Account for statistics reset time and normalized-query aggregation.

### Query plans

Collect `EXPLAIN (ANALYZE, BUFFERS, WAL, SETTINGS, FORMAT JSON)` only when safe and supported. Compare estimated and actual rows, loops, buffer activity, temp spills, sort/hash memory, parallel worker plans versus launches, and time concentration. Separate planning time from execution time.

### Indexes and data layout

Derive B-tree, hash, GIN, GiST, SP-GiST, BRIN, expression, partial, covering, or multicolumn indexes from operators and workload. Include index build locks, table/partition limitations, maintenance cost, HOT-update effects, bloat, and disk headroom. Verify validity and usage after concurrent builds.

### Concurrency and maintenance

Inspect wait events, blockers, long transactions, idle-in-transaction sessions, dead tuples, vacuum/analyze history, freeze risk, replication slots, and replication lag. Do not “rebuild fragmented indexes” as a generic PostgreSQL maintenance routine; diagnose bloat and cause first.

### Memory and connections

Treat `work_mem` as potentially multiplied per plan node and concurrent operation. Evaluate connection pooling, session state, prepared-plan behavior, and maximum concurrent memory before raising settings. Relate shared buffers and I/O settings to the operating system, storage, and measured workload.

## Verification

For each change record:

- baseline query ID, plan, load, and observation window;
- proposed mechanism and supported versions;
- before/after latency, throughput, buffers/I/O, WAL, locks, and resource use;
- write and maintenance regression risk;
- rollback trigger and monitoring window.

Never promise a percentage improvement before measurement.
