---
name: skill-review
description: Review a SKILL.md-based AI-agent skill and its evaluation evidence for activation quality, instruction design, progressive disclosure, operational safety, measurable value, and production readiness. Use for skill audits, approval decisions, activation investigations, and positive, negative, boundary, regression, or ablation evaluation design. Do not use for ordinary code, pull-request, security, API-schema, or performance reviews. Keep reviews and proposed improvements read-only; edit files only when the user explicitly asks to edit, update, fix, or implement changes.
---

# Skill Review

Assess the skill as a versioned software component whose value must be
demonstrated. Separate static design quality from observed runtime performance:
plausible instructions are not evidence that a skill works.

## Establish Scope and Evidence

1. Locate the complete skill directory, including `SKILL.md`, `agents/`,
   scripts, references, assets, tests, eval cases, run logs, and relevant
   repository instructions.
2. Establish the skill's intended users, supported agents/models, target tasks,
   exclusions, and production risk. Classify it as:
   - `capability`: supplies knowledge or procedures the base model may lack;
   - `preference`: encodes project- or organization-specific requirements; or
   - `mixed`.
3. Identify available evidence: validation results, eval definitions, repeated
   runs, baselines without the skill, failures, latency, token use, and cost.
4. Determine the applicable skill schema from repository instructions, the
   target agent's documentation, or its validator. Do not assume that one
   platform's optional metadata is valid on another.
5. Run safe, relevant static validators or existing evals when feasible. A
   read-only review may execute already available tools but must not install
   dependencies, populate new caches, make network calls, modify the skill,
   install hooks, deploy it, or invoke external model runs without
   authorization.
6. Mark claims as `observed`, `inferred`, or `untested`. Never convert the
   absence of evidence into a pass.
7. When bundled evaluations or release criteria are needed, read
   `references/evaluation.md` and `references/release-policy.md`. Use
   `scripts/evaluate.py` to validate, plan, run, or aggregate the bundled
   trigger and task-quality suites.

## Review the Skill

### Activation Contract

- Verify that frontmatter contains only the supported fields and that the name
  matches the directory.
- Treat the description as the activation contract. Check whether it says what
  the skill does and includes concrete task, artifact, and context triggers.
- Identify vague triggers that invite overactivation and missing synonyms or use
  cases that cause underactivation.
- Check meaningful exclusions when neighboring tasks or skills could collide.
- Route ordinary code or pull-request reviews, application security reviews,
  API-schema validation, and system or query performance benchmarks to their
  dedicated workflows.
- Flag behavior-critical activation guidance hidden in the body, because the
  body is unavailable until after activation.
- Inspect overlap with other installed skills and define a clear routing
  boundary when their descriptions compete.

### Instructions and Freedom

- Prefer directives that change observable behavior over background essays.
- Flag generic no-ops such as "write clean code" unless they are made specific
  and measurable.
- Require explicit outcomes, constraints, relevant tools/files, verification,
  and stop or escalation conditions where risk warrants them.
- Match freedom to task shape:
  - use deterministic scripts for fragile, repetitive transformations;
  - use bounded procedures when ordering and validation matter;
  - use principles and criteria when contextual judgment is essential.
- Check for stale versions, absolute machine paths, unavailable tools, secrets,
  unsafe mutations, contradictory instructions, and claims not supported by
  bundled resources.

### Progressive Disclosure

- Keep metadata discriminative and compact because it is always loaded.
- Keep `SKILL.md` focused on the core workflow and resource routing.
- Move detailed variants, schemas, examples, and reference material into
  directly linked resources when that reduces irrelevant context.
- Flag duplicate guidance, deep reference chains, orphan resources, generated
  clutter, and resources that the instructions never tell the agent to use.
- Judge size by behavioral value, not by an arbitrary line count; every section
  must earn its context cost.

### Verification and Operations

- Validate metadata, links, scripts, and syntax with deterministic checks where
  available.
- Require scripts to have representative execution tests and clear failure
  behavior.
- Check that evaluations measure task outcomes rather than a prescribed chain of
  tool calls, unless the route itself is a safety or compliance requirement.
- Review isolation, fixture control, agent/model/version recording, retry count,
  result retention, and reproducibility.
- Check whether deployment has review, regression gates, ownership, update
  policy, and rollback or retirement criteria proportional to risk.

## Design the Evaluation Matrix

Keep activation and task-quality evaluations separate:

- For activation, start with 8-10 realistic positive and 8-10 near-miss negative
  queries. Vary phrasing, explicitness, detail, and complexity; include
  ambiguous boundaries and known production failures. Keep a fixed validation
  split hidden from description-tuning decisions.
- For task quality, start with 2-3 representative cases containing a prompt,
  expected output, isolated input files, and outcome assertions. Expand only
  after initial runs expose consequential gaps.

For every case specify:

- stable ID and purpose;
- prompt and minimal isolated fixture;
- `should_trigger`;
- expected observable outcome;
- deterministic checks and prohibited patterns;
- rubric only for judgments that cannot be checked mechanically;
- applicable agents/models and required attempt count.

Prefer compilation, tests, assertions, schema validation, file inspection, and
command exit status over an LLM judge. Make every check capable of
distinguishing a plausible wrong result from the correct one.

Run or recommend repeated attempts because a single pass cannot establish
reliability. For activation, do not explicitly invoke the skill: verify that the
client actually loaded its `SKILL.md`. Report successes over attempts for each
case and aggregate positive activation recall, negative activation specificity,
task success, latency, tokens, and cost when those measurements are available.

## Measure Incremental Value

Use an ablation baseline: run the same isolated cases with and without the skill
under the same agent, model, tools, and attempt count.

Interpret results as follows:

| With skill | Without skill | Conclusion                             |
| ---------- | ------------- | -------------------------------------- |
| Better     | Worse         | Skill adds demonstrated value          |
| Same       | Same          | Skill may be redundant                 |
| Worse      | Better        | Skill harms performance                |
| Poor       | Poor          | Revisit the task, model, or evaluation |

Do not recommend production readiness solely from static review. For a
capability skill that no longer beats the baseline, recommend retirement while
retaining its evals as model regressions. For a preference skill, also assess
compliance value that a general model is not expected to learn.

## Calibrate Findings and Verdict

Assign severity from the concrete consequence and exposure:

- `critical`: plausible catastrophic or broadly exploitable harm requiring an
  immediate stop;
- `high`: release-blocking correctness, safety, security, or reliability defect;
- `medium`: material weakness that needs a scheduled fix or explicit risk
  acceptance;
- `low`: bounded improvement with limited operational consequence.

Use confidence separately from severity. Do not inflate missing evidence into a
demonstrated defect; report it as `unknown` unless the missing evidence itself
violates a required release process.

Apply verdicts consistently:

- `ready`: no blocking finding, all declared release thresholds pass across the
  supported matrix, and ablation shows non-negative value;
- `conditionally ready`: no blocking finding, but bounded evidence or rollout
  conditions remain and the proposed use is explicitly limited;
- `not ready`: a blocking finding exists or a declared release gate failed;
- `untested`: outcome evidence is insufficient and no observed blocking defect
  justifies `not ready`.

Require owners to declare thresholds before evaluation. If none exist, propose
risk-proportionate thresholds and label them as recommendations; do not invent a
passing production gate after seeing results. At minimum require repeated
attempts, zero safety-policy violations, no regression in negative specificity,
and a task-success result that meets the intended service level.

## Report

Use the user's language and lead with actionable findings ordered by severity.
For every finding provide evidence, consequence, confidence, and the smallest
credible remediation.

Include:

1. **Verdict** — `ready`, `conditionally ready`, `not ready`, or `untested`;
2. **Findings** — activation, instructions, disclosure, verification, safety,
   and operations;
3. **Evidence matrix** — `pass`, `finding`, `unknown`, or `not applicable`;
4. **Evaluation plan or results** — cases, attempts, metrics, and ablation;
5. **Recommended gate** — concrete conditions to ship, revise, or retire.

Requests to review, assess, suggest, recommend, or propose improvements remain
read-only. Edit files only when the user explicitly asks to edit, update, fix,
apply, or implement changes. When edits are authorized, make the smallest
changes that address validated findings, add regression cases for changed
behavior, and re-run available validation afterward.
