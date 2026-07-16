---
name: test-design
description: Design or improve a focused software test strategy from risks, contracts, and system boundaries. Use when deciding what to test, choosing unit/integration/contract/system/property tests, creating high-value test cases, replacing brittle mocks, or reviewing a test suite's coverage and trustworthiness. Do not use for merely running existing tests or debugging an unknown failure.
---

# Test Design

Design the smallest test portfolio that gives useful, trustworthy feedback about important behavior.

## Workflow

1. Identify the decision the tests must support and the failure risks: wrong result, invalid state, unsafe side effect, integration drift, performance, security, recovery, or compatibility.
2. Turn requirements and observed behavior into explicit contracts: inputs, outputs, invariants, state transitions, side effects, errors, and operational limits.
3. Map each risk to the lowest test boundary that can observe it faithfully. Use a higher boundary when the behavior depends on real serialization, storage, processes, concurrency, permissions, networks, or third-party contracts.
4. Partition the input and state space. Cover normal cases, boundaries, invalid classes, empty/zero/null, ordering, duplicates, retries, partial failure, concurrency, and historical regression cases where relevant.
5. Choose an oracle that can distinguish correct from plausible-looking output. Prefer domain invariants, reference implementations, metamorphic relations, snapshots only for intentionally reviewed stable output, and production-compatible contract fixtures.
6. Control nondeterminism explicitly: clocks, randomness, scheduling, IDs, network, filesystem, locale, and external services. Preserve the behavior under test; do not mock it away.
7. Implement tests around observable behavior. Keep setup legible, failures diagnostic, and test data minimal but semantically meaningful.
8. Prove the test can fail for the intended defect when practical, then run the narrow test and relevant broader suite.
9. Remove redundant or misleading tests. Record residual risks that require monitoring, staged rollout, manual testing, or a production experiment.

Read [test selection and failure modes](references/test-selection.md) for boundary choices, doubles, properties, concurrency, and suite review.

## Quality rules

- A unit is a behavior boundary, not necessarily a method or class.
- Do not optimize for test count or line coverage. Use coverage to find unexamined behavior, never as proof of correctness.
- Avoid tests that duplicate implementation steps, assert private structure, or mock every collaborator.
- A test should fail for one understandable reason and explain the violated contract.
- Keep slow tests if they cover a unique high-risk boundary; isolate and schedule them appropriately.
- Never claim a test or suite passed without inspecting the actual result.

## Output

Provide a risk-to-test matrix or concise equivalent, concrete cases and oracles, required fixtures/doubles, execution order, commands actually run, and remaining untested risks.
