---
name: refactor-method-complexity-reduce
description: Reduce a specified method's measured cognitive complexity to a stated threshold while preserving behavior, primarily through focused extraction and control-flow simplification. Use only when the target method, metric, and threshold are explicit. For general cleanup use refactor; for plan-only work use refactor-plan.
---

# Reduce Method Complexity

Treat the metric as a constraint, not the design goal. Improve the method's comprehensibility without exporting complexity into poorly named helpers.

## Workflow

1. Locate the exact method and the configured analyzer/rule. Record the current measured value and required threshold.
2. Read callers, overrides/interfaces, tests, error behavior, state mutation, ordering, and concurrency assumptions.
3. Run focused tests or add characterization coverage for branches that will move.
4. Identify complexity sources: nested decisions, mixed responsibilities, complex predicates, repeated branches, loops, and error paths.
5. Apply small transformations: guard clauses, named predicates, focused extraction, decomposition by responsibility, or simpler dispatch. Preserve evaluation order, short-circuiting, side effects, async behavior, and exceptions.
6. After each coherent step, compile/type-check and run the narrow tests.
7. Run the same analyzer and confirm the target method—not merely a file average—is at or below the threshold. Check that helpers remain cohesive and are not metric gaming.
8. Run relevant broader tests and report exact analyzer/test results.

## Guardrails

- Do not change public behavior, validation order, exception contracts, or performance-sensitive ordering without explicit approval.
- Do not replace clear conditionals with unnecessary patterns, tuples, mutable flags, or generic helpers solely to satisfy the metric.
- Do not claim success when the analyzer is unavailable; report that verification gap.
- Stop once the agreed threshold and readability objective are met.
