---
name: tiger-style
description: Apply TigerBeetle's TigerStyle approach to design, implement, or review bounded high-integrity systems code with safety before performance before developer experience. Use when the user explicitly requests TigerStyle or TigerBeetle coding style, a repository adopts it, or a task calls for its NASA Power of Ten-inspired constraints such as bounded work, startup-only allocation, assertion-rich invariants, and up-front resource sketches. Do not use for generic code review, ordinary refactoring, incident debugging, or performance tuning without this policy context.
---

# Tiger Style

Engineer small, predictable systems by making safety and resource constraints
explicit before implementation.

## Establish applicability

1. Confirm that the request or repository explicitly adopts TigerStyle. Treat
   its hard limits as project policy, not universal advice.
2. Record the code path, language, workload, failure model, and compatibility
   constraints in scope.
3. Separate strict TigerStyle requirements from language-specific translations.
   Preserve repository conventions where they do not weaken an adopted
   constraint.
4. Escalate conflicts instead of silently relaxing them, especially dynamic
   allocation after initialization, unbounded work, recursion, or dependency
   additions.

## Workflow

1. Rank the design goals in this order: safety, performance, developer
   experience. State any concrete trade-off where one goal constrains another.
2. Define limits before code: maximum input, iterations, queue depth, memory,
   concurrency, retries, and work per event or time slice. Assert the event-loop
   exception when a loop is intentionally perpetual.
3. Sketch network, disk, memory, and CPU latency and bandwidth. Include access
   frequency so a frequent fast operation can outweigh an infrequent slow one.
4. Design ownership and lifecycle. Allocate required memory during
   initialization, avoid later allocation or reallocation, construct large or
   immovable values in place, and keep mutable state single-owned.
5. Keep control flow simple and explicit. Do not use recursion. Centralize
   branching in orchestration functions, push uniform iteration into helpers,
   and keep leaf functions pure where practical.
6. Encode the mental model as contracts. Distinguish programmer errors, which
   assert and stop, from expected operating errors, which must be handled.
   Assert arguments, results, invariants, compile-time relationships, and both
   valid and invalid boundaries. Pair important assertions across independent
   paths.
7. Implement with explicitly sized types, narrow scopes, explicit library
   options, complete error handling, and functions no longer than 70 lines. Keep
   lines within 100 columns and use the repository formatter and strictest
   warning settings.
8. Decouple external events from immediate internal work. Admit, queue, and
   batch bounded work so the program retains control over scheduling and
   overload.
9. Test normal, boundary, invalid, transition, and error-handling paths. Add
   fuzzing or deterministic simulation where the state space warrants it, while
   retaining human reasoning and explicit oracles.
10. Measure after the design sketch. Compare predictions with profiles or
    benchmarks, explain discrepancies, and optimize the dominant
    frequency-weighted resource without weakening safety.
11. Review every new dependency and tool as a safety, performance, supply-chain,
    and operational cost. Under a strict TigerStyle policy, reject runtime
    dependencies beyond the approved toolchain.

Read [the review checklist](references/review-checklist.md) when reviewing a
design or diff, translating the rules to a non-Zig language, or reporting
exceptions.

## Decision rules

- Reject a bound that exists only in documentation; make it enforced by a type,
  capacity, assertion, admission rule, or test.
- Prefer a small, direct implementation over an abstraction unless the
  abstraction makes the domain and its invariants easier to verify.
- Reject default arguments at important library call sites; spell out behavior
  that could change across versions.
- Keep index, count, size, and unit conversions visible and checked. State
  division and rounding intent explicitly.
- Explain why a non-obvious decision is correct. Use comments for rationale and
  test methodology, not narration of syntax.
- Do not claim safety from assertions, fuzzing, coverage, or formatting alone.
  Connect each claim to a model, invariant, test, and observed result.

## Output

Report:

- applicability and adopted constraints;
- enforced bounds and the four-resource sketch;
- safety, performance, and developer-experience findings in that priority order;
- changes or recommendations, including rejected alternatives;
- assertions, tests, measurements, and commands actually run;
- explicit exceptions, residual risks, and unverified assumptions.
