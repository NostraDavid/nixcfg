# Relational design review

## Contents

- Requirements
- Entity and attribute structure
- Keys and relationships
- Integrity and lifecycle
- Physical design
- Validation

## Requirements

- Give the database a specific purpose and list the operations users and systems must perform.
- Identify sources of truth, data owners, consumers, retention rules, and recovery objectives.
- Quantify current and expected row counts, write rates, read shapes, concurrency, and acceptable latency when physical choices depend on them.
- Separate confirmed requirements from assumptions and future possibilities.

## Entity and attribute structure

- Make each table represent one subject or relationship.
- Split multipart values only when their components have independent meaning or operations.
- Move repeating or multivalued attributes to a related table.
- Find hidden subtypes before adopting entity-attribute-value storage.
- Avoid storing derived values unless recomputation is too costly and staleness is controlled.

## Keys and relationships

- List every candidate key before selecting a primary key.
- Retain uniqueness constraints for business identifiers when a surrogate primary key is added.
- Define optionality and cardinality in both directions.
- Use foreign keys where the database owns referential integrity; document deliberate external references.
- Specify update and delete behavior from lifecycle rules rather than defaulting to cascade, restrict, soft delete, or hard delete.

## Integrity and lifecycle

- Translate field rules, relationship rules, and cross-row business rules into enforceable constraints or named transactional checks.
- Model time zones, effective periods, history, and deletion explicitly where required.
- Treat nullability as a domain decision, not a convenience.
- Identify invariants that span services or databases and explain where they are enforced.

## Physical design

- Match types to domains, range, precision, collation, and arithmetic semantics.
- Derive indexes from real predicates, joins, ordering, grouping, and uniqueness requirements.
- Include write amplification, storage, maintenance, and lock costs in every index or denormalization decision.
- Use JSON, arrays, full-text search, partitioning, generated columns, and engine extensions only when their query and integrity tradeoffs are understood.

## Validation

- Test valid and invalid inserts, updates, deletes, and concurrent transitions.
- Exercise boundary values, absent values, duplicate identities, orphan prevention, and lifecycle changes.
- Verify representative reads against realistic data volume.
- Review the model with domain stakeholders before treating DDL as final.
