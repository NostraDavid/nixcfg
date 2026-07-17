---
name: review-twelve-factor-app
description: Review a service application's repository, architecture, configuration, delivery pipeline, and runtime practices against the original Twelve-Factor App methodology. Use for twelve-factor or 12-factor assessments, factor-by-factor gap analyses, cloud-readiness reviews explicitly based on 12factor.net, and modernization backlogs organized by the twelve factors. Do not use for a generic code-quality, security, reliability, or CI/CD review unless Twelve-Factor criteria are requested.
---

# Review Twelve-Factor App

Assess observable evidence against the methodology without turning preferences
into findings or claiming certainty that the available artifacts cannot support.

## Workflow

1. Define the application boundary: user-facing service, workers, scheduled
   jobs, admin processes, backing services, deploys, and independently
   deployable components. In a monorepo, assess each application separately when
   its lifecycle differs.
2. Establish the evidence boundary. Inspect source, manifests, lockfiles,
   container definitions, infrastructure, delivery configuration, and
   operational documentation. Ask for or mark missing evidence about actual
   build, release, runtime, scaling, shutdown, and administrative behavior.
3. Read [review criteria](references/review-criteria.md) and assess all twelve
   factors. Mark a factor `not applicable` only when its premise truly does not
   exist, such as port binding for a worker that exports no network service.
4. Assign one status per factor:
   - `pass`: direct evidence satisfies the canonical intent.
   - `partial`: some requirements hold, or a modern equivalent preserves the
     intent but differs from the original prescription.
   - `fail`: direct evidence contradicts the factor and creates a practical
     portability, deployment, or scaling gap.
   - `unknown`: evidence is insufficient; state exactly what would resolve it.
   - `not applicable`: explain why the factor has no relevant surface.
5. Keep confidence separate from status. Use `high`, `medium`, or `low`
   confidence based on evidence quality; never convert missing evidence into
   failure.
6. Report actionable findings before the factor summary. For each finding, give
   severity, factor, evidence with file and line where possible, consequence,
   and smallest credible remediation. Rank severity by demonstrated impact, not
   by factor number.
7. Summarize every factor in a compact matrix, then provide evidence requests
   and a prioritized improvement plan. Preserve explicit trade-offs and
   intentional deviations.

## Review Rules

- Treat Twelve-Factor as a methodology for service applications, not a
  certification, security standard, or complete production-readiness model.
- Judge deploy-varying configuration, not every configuration file. Static
  routes, dependency wiring, and other invariant application behavior may remain
  in code.
- Distinguish canonical adherence from modern equivalence. For example, a secret
  mounted by an orchestrator can preserve separation from code while not
  literally using an environment variable. Record both facts instead of forcing
  a binary verdict.
- Accept containers, virtual environments, hermetic builds, and declarative
  system packages as dependency isolation when the resulting runtime
  dependencies are explicit and reproducible.
- Do not infer runtime behavior solely from framework defaults or manifests.
  Seek tests, pipeline history, platform settings, metrics, or operator
  documentation where behavior matters.
- Do not require every application to use microservices, containers, Kubernetes,
  or a particular cloud provider.
- Do not modify the reviewed application unless the user separately asks for
  implementation.

## Output

Use the user's language. If there are no actionable findings, say so explicitly
and still list unknowns.

1. **Scope and evidence**: application boundary, artifacts reviewed, and
   material limitations.
2. **Findings**: ordered by severity; omit factors without an actionable defect.
3. **Factor matrix**: factor, status, confidence, decisive evidence, and main
   gap or rationale.
4. **Evidence requests**: only information needed to resolve `unknown` or
   low-confidence judgments.
5. **Prioritized plan**: immediate risk reduction, structural improvements, and
   optional canonical-alignment work.

Avoid a single percentage score: it hides unequal consequences and unsupported
judgments.
