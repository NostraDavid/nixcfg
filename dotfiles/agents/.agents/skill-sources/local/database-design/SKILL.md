---
name: database-design
description: Design or review a relational database schema from domain requirements, business rules, data lifecycles, and workload evidence. Use when defining entities, keys, relationships, constraints, normalization boundaries, data types, or a physical schema for a new or substantially redesigned database. Do not use for tuning one slow query, reviewing an existing SQL patch, or planning an evolutionary production migration.
---

# Database Design

Design from information requirements and invariants before choosing product-specific features.

## Workflow

1. Establish the database mission, stakeholders, supported decisions, and operations.
2. Record facts that materially affect the design:
   - database engine and supported versions;
   - transactional and analytical workloads;
   - expected volume, growth, concurrency, and latency;
   - retention, deletion, audit, privacy, and recovery requirements;
   - existing systems, identifiers, and ownership boundaries.
3. Ask for missing facts only when different answers produce materially different schemas. State assumptions otherwise.
4. Model the domain independently of the selected RDBMS:
   - identify one subject per entity;
   - name candidate keys and the business meaning of identity;
   - define cardinality, optionality, temporal meaning, and lifecycle;
   - express business rules as testable invariants.
5. Produce the logical schema:
   - keep attributes atomic for the required operations;
   - remove repeating groups and unintended dependencies;
   - resolve many-to-many relationships with an associative entity;
   - distinguish unknown, inapplicable, and not-yet-recorded values before allowing nulls;
   - prefer declarative keys, foreign keys, uniqueness, and checks over application-only validation.
6. Produce the physical schema only after the logical model is coherent. Select types, identifiers, indexes, partitioning, and denormalization from engine capabilities and measured access patterns.
7. Validate the design with representative records, invalid records, lifecycle transitions, deletion behavior, concurrent writes, and the highest-value reads.
8. Deliver the schema together with assumptions, unresolved decisions, invariant tests, and tradeoffs.

## Decision rules

- Treat a surrogate key as an implementation choice, not proof that the natural candidate keys are irrelevant. Preserve required business uniqueness.
- Normalize to remove update anomalies; denormalize only for a named workload with an explicit consistency mechanism and measurement plan.
- Store multivalued attributes in related tables unless the selected engine, query patterns, and integrity requirements justify a native collection type.
- Reject comma-delimited foreign keys, generic entity-attribute-value models, polymorphic foreign keys without enforceable integrity, and cloned tables used as ad hoc partitioning unless their constraints make the tradeoff explicit.
- Do not prescribe UUIDs, timestamps, soft deletes, JSON, enums, or partitioning universally. Each solves a particular requirement and introduces costs.
- Separate presentation shape from storage shape. Reports and API payloads do not determine table boundaries.

## Review checklist

Read [references/design-review.md](references/design-review.md) before finalizing a non-trivial schema. Use only the sections relevant to the requested design.

## Output

Return:

1. requirements and assumptions;
2. conceptual entities and relationships;
3. logical schema with keys and invariants;
4. physical DDL when an engine is known;
5. workload-driven index candidates, not speculative indexes;
6. validation scenarios and open risks.
