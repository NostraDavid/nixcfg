---
name: refactor
description: Surgically improve existing code structure while preserving observable behavior. Use for extracting or moving responsibilities, clarifying names and data flow, reducing duplication or coupling, introducing seams around dependencies, or making legacy code safer to change. Do not use for a rewrite, behavior-changing feature work, a plan-only multi-file refactor, or a database migration.
---

# Refactor

Change structure in small verified steps while keeping the behavioral contract stable.

## Workflow

1. Inspect repository instructions, callers, tests, runtime configuration, and the change pressure that makes the current design costly.
2. State the behavior to preserve: public API, outputs, errors, side effects, ordering, persistence, timing or resource constraints that are contractual, and compatibility boundaries.
3. Establish feedback. Run focused existing tests; where coverage is insufficient, add characterization tests around observed behavior or create a narrow seam for observation.
4. Select one structural objective and the smallest transformation that advances it. Prefer named refactorings and reversible edits over pattern-driven redesign.
5. Apply one coherent step. Update callers mechanically, then run the nearest useful test or static check before continuing.
6. Reassess the code after each step. Stop when the stated change pressure is resolved; do not “clean up” unrelated areas.
7. Run targeted and proportionate broader verification. Review the diff for accidental behavior changes, compatibility breaks, dead code, and needless abstraction.
8. Report the preserved contract, transformations made, checks and results, and any uncertainty that remains.

## Decision rules

- Extract code when it creates a useful name, isolates a responsibility, or opens a test seam—not merely to shorten a method.
- Move behavior toward the data or invariant it primarily owns, while respecting dependency direction and lifecycle.
- Encapsulate mutable data before changing its representation.
- Replace conditionals with polymorphism or tables only when variation is stable and the new dispatch is simpler.
- Delay abstraction until duplicated code represents the same concept and changes for the same reason.
- In legacy code, break dependencies at narrow seams before invasive restructuring.
- Keep refactoring separate from behavior changes when possible. If inseparable, label the semantic change and test it explicitly.

## Guardrails

- Do not assume tests prove all behavior; inspect contracts and production-facing boundaries.
- Preserve exception types/messages, serialization, database effects, concurrency, and ordering when consumers may depend on them.
- Avoid speculative design patterns, broad renames, dependency upgrades, formatting churn, and unrelated cleanup.
- Never claim behavior preservation without showing the evidence used.
