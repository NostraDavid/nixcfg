---
name: sql-code-review
description: Review SQL and relational schema changes for correctness, security, integrity, portability, and maintainability across SQL databases. Use for SQL files, migrations, views, stored routines, ORM-emitted SQL, or database patches when the user wants findings rather than performance tuning. Defer engine-specific PostgreSQL behavior to postgresql-code-review and measured performance diagnosis to sql-optimization.
---

# SQL Code Review

Report only actionable findings supported by the supplied code and repository context.

## Workflow

1. Resolve the requested diff or file scope and identify the SQL dialect and supported versions from repository evidence.
2. Trace inputs and execution context: parameter binding, dynamic identifiers, caller privileges, transaction ownership, and error handling.
3. Reconstruct affected tables, keys, relationships, constraints, views, routines, and migration order before judging a statement in isolation.
4. Review in this order:
   - destructive or irreversible behavior;
   - injection and privilege boundaries;
   - correctness under nulls, duplicates, empty sets, and multi-row results;
   - keys, referential integrity, checks, and transaction atomicity;
   - deployment compatibility and rollback assumptions;
   - maintainability and portability promised by the project.
5. Use performance concerns only when the code shows a credible mechanism. Route plan-based tuning to `sql-optimization`.
6. Verify dialect-sensitive claims against current official documentation.
7. Return findings ordered by severity. If none remain after verification, say so and state residual testing gaps.

## Review heuristics

- Require values to use bound parameters. Treat dynamic identifiers separately because bind parameters generally cannot represent them; use strict allowlists and dialect-safe quoting.
- Check predicates and joins for unintended multiplicity, missing rows, three-valued logic, and nondeterministic selection.
- Treat `DISTINCT`, arbitrary grouping, and broad null substitution as possible attempts to hide a modeling or join error.
- Flag comma-delimited relationships, unenforced polymorphic references, generic EAV tables, repeating columns, missing keys, and application-only invariants when they create a concrete integrity failure.
- Do not demand `SELECT *` removal, a surrogate key, soft deletes, cascades, normalization, or denormalization without a demonstrated contract or failure.
- For migrations, check existing data, lock/transaction behavior, mixed application versions, resumability, and whether rollback can actually restore information.
- Do not assign numeric quality scores or speculative percentage improvements.

## Finding format

For each finding include:

- severity and concise title;
- exact location;
- failing scenario or attack path;
- evidence and affected invariant;
- minimal correction;
- validation needed when the conclusion depends on runtime data or an execution plan.

Keep non-blocking style preferences out of the findings list unless the repository explicitly enforces them.
