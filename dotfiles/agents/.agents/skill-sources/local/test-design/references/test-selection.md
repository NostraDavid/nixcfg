# Test selection and failure modes

## Select the boundary

| Risk                                  | Usually start with                      | Escalate when                                 |
| ------------------------------------- | --------------------------------------- | --------------------------------------------- |
| Pure decision or transformation       | unit/property test                      | behavior depends on runtime integration       |
| Database constraint, query, migration | real database integration test          | rollout or replication behavior matters       |
| Service protocol                      | consumer/provider contract test         | infrastructure or auth path changes semantics |
| User workflow                         | focused system test                     | component tests cannot observe the outcome    |
| Retry/idempotency/recovery            | integration test with controlled faults | multi-process timing is material              |
| Race or ordering                      | deterministic concurrency test          | only production scheduler/load reproduces it  |
| Performance budget                    | benchmark or load test                  | capacity and shared-resource effects matter   |

## Test doubles

- **stub:** supplies controlled data;
- **fake:** working but simplified implementation;
- **spy:** records interactions for later assertions;
- **mock:** encodes an expected interaction protocol.

Use a double only across an owned boundary whose real behavior is not the subject of the test. Prefer realistic fakes or contract-checked adapters over deep mock graphs. Interaction assertions are appropriate when the interaction itself is the contract, such as publishing exactly one event.

## Strong case-design techniques

- equivalence partitions and boundary values;
- decision tables for interacting rules;
- state-transition tests for lifecycles;
- property-based testing for broad generated spaces;
- metamorphic tests when exact expected values are expensive;
- pairwise/combinatorial selection for configuration interactions;
- mutation testing to assess whether assertions detect plausible defects;
- differential tests against a trusted previous or reference implementation.

## Suite anti-patterns

- happy-path-only coverage;
- implementation-coupled tests that block safe refactoring;
- shared mutable fixtures and order dependence;
- arbitrary sleeps and retries hiding nondeterminism;
- snapshots so large that reviewers approve changes blindly;
- mocks that allow an impossible production interaction;
- tests without a meaningful oracle;
- duplicated cases that add runtime but no distinct risk coverage;
- quarantined flaky tests without owner, evidence, and removal criterion.
