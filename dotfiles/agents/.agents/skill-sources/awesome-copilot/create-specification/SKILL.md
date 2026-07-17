---
name: create-specification
description: Create or substantially revise a repository specification that turns stakeholder goals into scoped, traceable, testable requirements and interfaces. Use for feature, system, API, data, infrastructure, process, or architecture specifications. Do not use for an implementation plan, ADR, README, or formal TLA+ model unless explicitly requested.
---

# Create Specification

Discover the repository's convention first. A specification states required observable behavior and constraints; it should not invent implementation choices or force a universal template.

## Workflow

1. Read repository instructions and locate existing specs, templates, terminology, architecture decisions, code/interfaces, tests, and ownership. Follow the local path, naming, and frontmatter convention.
2. Establish purpose, stakeholders and interests, system boundary, design scope, actors/external systems, goals, assumptions, dependencies, non-goals, and unresolved decisions.
3. Write the primary success scenarios as actor-goal interactions. Add alternatives and failure conditions with required system responses; keep UI/implementation detail out unless it is a constraint.
4. Define functional requirements as stable, uniquely identified, atomic, necessary, feasible, and verifiable statements. Use “shall” only for binding behavior.
5. Express quality requirements as measurable scenarios with stimulus, environment, affected artifact, response, and measure.
6. Define interfaces/data contracts, state transitions, invariants, authorization/privacy rules, error semantics, compatibility/versioning, lifecycle/retention, and operational/recovery behavior where relevant.
7. Link acceptance criteria and verification to requirements. Include boundary, negative, abuse, failure, concurrency, migration, and recovery cases according to risk; do not prescribe a framework without evidence.
8. Record rationale, dependencies, open questions, risks, rejected scope, and traceability to ADRs or authoritative sources. Keep facts, decisions, and assumptions distinct.
9. Check for ambiguity, contradictions, unstated actors, missing failure handling, unverifiable adjectives, solution bias, and requirements without acceptance evidence.
10. Write the file only when requested, then validate links/format and report assumptions and remaining decision gates.

## Optional formalization

Use a state table, decision table, sequence, or executable/property model when ordinary prose cannot make concurrency, temporal behavior, or invariants unambiguous. Use TLA+ only when requested or when the repository already uses it; a formal model complements rather than replaces the stakeholder-facing specification.

## Minimum output

- purpose, scope, stakeholders, actors, assumptions, non-goals;
- scenarios including failures;
- identified requirements and measurable quality attributes;
- interfaces, data/state/security/operational contracts as relevant;
- acceptance and validation mapping;
- dependencies, risks, open decisions, and traceability.
