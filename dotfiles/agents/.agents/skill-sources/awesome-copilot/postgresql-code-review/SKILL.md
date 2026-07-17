---
name: postgresql-code-review
description: Review PostgreSQL SQL, DDL, migrations, functions, triggers, roles, row-level security, and PostgreSQL-specific data types for correctness, security, integrity, and maintainability. Use when a review depends on PostgreSQL semantics or catalog behavior. Use sql-code-review for portable SQL and postgresql-optimization for measured performance tuning.
---

# PostgreSQL Code Review

Apply the generic `sql-code-review` workflow, then inspect PostgreSQL-specific behavior.

## Version and context

Identify the supported PostgreSQL versions, extensions, migration framework, application role, object owners, connection-pool behavior, and deployment topology. Verify version-sensitive claims in the current official PostgreSQL documentation.

## Review areas

### Types and integrity

- Check `timestamptz` versus `timestamp` from domain semantics; neither is universally correct.
- Check `numeric`, floating point, collation, domains, enums, arrays, ranges, JSONB, and generated values against their required operations and evolution costs.
- Prefer identity columns for new sequence-backed identifiers when project/version compatibility permits, while recognizing existing `serial` schemas as valid.
- Require JSONB and arrays to have explicit shape, integrity ownership, and query reasons; do not recommend them merely because PostgreSQL supports them.
- Check exclusion, unique, foreign-key, and check constraints for the intended null and concurrency behavior.

### Functions, triggers, and views

- Review volatility, parallel-safety, leakproof assumptions, `SECURITY DEFINER`, fixed `search_path`, exception behavior, and transaction effects.
- Treat triggers as hidden coupling: verify recursion, firing order, multi-row statements, transition behavior, replication implications, and observability.
- Check view security options, ownership, updatability assumptions, and dependency effects during migrations.

### Roles and row-level security

- Review ownership separately from granted privileges and default privileges.
- Check public schema/function exposure and unsafe `search_path` resolution.
- Verify RLS enablement, force behavior, policy commands and roles, `USING` versus `WITH CHECK`, owner/superuser bypass, and application session context.
- Treat extensions as trusted code and verify install schema, privileges, necessity, and supported versions.

### Migrations

- Check lock level, table rewrites, existing invalid data, mixed application versions, and recovery.
- Remember that `CREATE INDEX CONCURRENTLY` cannot run inside a transaction block and can leave an invalid index after failure.
- Check partitioned-table and constraint-specific limitations before recommending concurrent operations.

## Findings

Report the exact PostgreSQL mechanism, affected versions, failing scenario, minimal fix, and a verification query or test. Do not recommend extensions, enum types, UUID generators, RLS, partitioning, or specialized indexes by default.
