---
name: refactor-plan
description: Investigate and plan a multi-file or high-risk code refactor without editing implementation files. Use when the user asks for a refactor plan, sequencing, scope, migration path, or review gate before implementation. Do not use for a small refactor the user asked to implement now.
---

# Refactor Plan

Produce an evidence-backed execution plan, then stop before implementation.

## Workflow

1. Read repository instructions and inspect implementation, callers, tests, configuration, generated artifacts, and deployment boundaries.
2. Define the current state, target state, change pressure, observable behavior to preserve, and explicit non-goals.
3. Map affected files, ownership boundaries, public contracts, data/control flow, dependencies, and hidden coupling. Cite concrete paths and symbols.
4. Identify where current tests give feedback and where characterization, contract, migration, or compatibility tests are required first.
5. Sequence small, reversible phases with an independently verifiable safe state after each. Put enabling seams and compatibility layers before dependent changes; remove them only after consumers migrate.
6. For each phase give exact files/symbols, action, prerequisites, validation, rollback, and exit criteria.
7. List risks, unknowns, decision gates, rollout/observability needs, and changes intentionally deferred.
8. Present the plan and wait for confirmation. Do not edit implementation files while preparing it.

## Output

Include:

- current and target state;
- preserved contracts and non-goals;
- affected-file/dependency map;
- ordered phases with per-phase checks and safe states;
- rollback/recovery and compatibility strategy;
- risks, assumptions, open decisions, and final validation commands.

If the repository does not contain enough evidence to choose between materially different designs, ask the smallest blocking question instead of inventing a plan.
