---
id: ADR-SYS-0001
title: Use PostgreSQL for orders
status: ACCEPTED
domain: SYS
system: Orders
owner: Orders team
decider: Architecture group
decision_date: 2026-01-15
last_reviewed_date: 2026-01-16
supersedes: []
superseded_by: []
related: []
---

# Use PostgreSQL for orders

`ADR-SYS-0001`

## Context and Problem Statement

The orders service needs transactions across orders and their line items. The
team already operates PostgreSQL and has no production document-store support.

## Decision Outcome

**Chosen option:** PostgreSQL

Use PostgreSQL because it provides the required transaction model and matches
the team's operational experience. These drivers outweigh flexible documents.

## Participants

The orders team operates the service; the architecture group approves this
decision and customer support depends on consistent order records.

## Consequences

### Positive

Orders and line items can be committed together using existing operational
skills.

### Negative

Schema migrations require coordination with application releases.

### Neutral

The team continues to own backup and restore exercises.

## Decision Drivers

| Driver      | Relative weight | Description                                     |
| ----------- | --------------- | ----------------------------------------------- |
| Consistency | High            | Orders and line items must commit together.     |
| Operations  | Medium          | Reuse database skills already held by the team. |

## Considered Options

| Option         | Summary                                                     |
| -------------- | ----------------------------------------------------------- |
| PostgreSQL     | Relational storage with transactions and explicit schema.   |
| Document store | Flexible order documents in a separately operated database. |

### Pros and Cons of the Options

#### PostgreSQL

Selected because transactions and operational familiarity match both drivers.

##### Pros and Cons

- Good, because the team can operate the transaction model.
- Neutral, because backup ownership remains with the orders team.
- Bad, because schema changes need release coordination.

#### Document store

Rejected because a new operational stack does not address a demonstrated need.

##### Pros and Cons

- Good, because individual order shapes can evolve independently.
- Neutral, because backup ownership would still remain with the orders team.
- Bad, because the team would need a new operational capability.

## More Information

This is synthetic evaluation data, not a real approval. Revisit if order access
patterns change enough that relational constraints no longer fit.
