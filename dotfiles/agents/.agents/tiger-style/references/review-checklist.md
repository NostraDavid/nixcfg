# TigerStyle review checklist

Use this checklist after reading the target repository's own instructions. Mark
each item as satisfied, violated, not applicable, or unverified; do not infer
compliance from absence of evidence.

## Applicability and design

- Is TigerStyle explicitly requested or adopted by the repository?
- Are safety, performance, and developer experience evaluated in that order?
- Are expected operating failures separated from programmer errors?
- Are the domain model, state transitions, ownership, and failure boundaries
  understandable without reconstructing hidden behavior?
- Does each abstraction reduce verification cost enough to justify its own
  failure modes?

## Bounds and resources

- Does every input, loop, queue, batch, retry, allocation, and unit of
  concurrent work have an enforced upper bound?
- Is a perpetual loop intentionally identified and asserted as such?
- Is memory reserved during initialization with no allocation, free, or
  reallocation in the operating phase?
- Are large or pointer-stable values initialized in place?
- Does a rough sketch cover network, disk, memory, and CPU latency, bandwidth,
  and access frequency?
- Are external events admitted and batched at the program's pace rather than
  driving unbounded immediate work?

## Control flow and state

- Is control flow explicit, non-recursive, and easy to enumerate?
- Are compound conditions split when that makes positive and negative cases
  independently verifiable?
- Does the orchestration function own branching while helpers perform focused,
  preferably pure work?
- Does each function fit within 70 lines without hiding control flow behind
  arbitrary extraction?
- Are variables introduced near use and held in the smallest practical scope?
- Is mutable state single-owned, without aliases or duplicated derived values
  that can drift?
- Do functions run to completion without suspension where contracts rely on
  stable preconditions?

## Contracts and errors

- Are arguments, return values, preconditions, postconditions, and invariants
  asserted where programmer mistakes would corrupt state?
- Are important invariants checked through at least two independent paths when
  practical?
- Are both the expected valid space and the invalid boundary asserted and
  tested?
- Are compile-time constant relationships, sizes, and layout assumptions
  checked?
- Are assertions simple and diagnostic rather than compound?
- Is every signaled operating error handled, propagated, or deliberately
  converted with documented semantics?
- Are padding and partially filled buffers initialized so unused bytes cannot
  leak or break determinism?

## Types, APIs, and naming

- Are integer widths explicit and conversions checked?
- Are index, count, size, duration, rate, and byte units visible in names or
  types?
- Is rounding intent explicit for division?
- Are potentially confusable arguments named or grouped into an options value?
- Are important library options explicit at the call site rather than inherited
  from defaults?
- Do nouns and verbs reflect the domain without ambiguous abbreviations or
  overloaded terminology?
- Are related declarations ordered so readers encounter the principal control
  flow first?

## Tests and evidence

- Do tests cover normal, boundary, invalid, transition, and error-handling
  cases?
- Can the chosen oracle distinguish correctness from a plausible result?
- Does fuzzing or deterministic simulation amplify explicit invariants instead
  of replacing a human model?
- Are performance claims checked against representative measurements after an
  up-front estimate?
- Are strict compiler warnings, the repository formatter, and the 100-column
  limit enforced?
- Is every dependency or tool addition justified against safety, performance,
  supply-chain, startup, and maintenance costs?

## Translation notes

- Apply semantic constraints across languages; do not copy Zig syntax into
  another language.
- Use the language's checked arithmetic, fixed-capacity containers, compile-time
  checks, and lint configuration where available.
- If a runtime makes startup-only allocation impossible, expose the conflict and
  ask for a documented exception or a different implementation boundary.
- Do not weaken an adopted hard rule merely because a framework normally hides
  allocation, retries, scheduling, or default options.
