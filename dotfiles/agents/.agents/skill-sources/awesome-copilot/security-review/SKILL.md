---
name: security-review
description: Review an existing codebase or scoped path for exploitable software vulnerabilities by modeling trust boundaries and tracing attacker-controlled data and state to security impact. Use for repository security audits, auth/access-control review, injection, secrets exposure, unsafe cryptography, supply-chain configuration, and business-logic abuse. Do not use for greenfield security design, offensive exploitation, a supplied finding that only needs validation, or applying fixes unless explicitly requested.
---

# Security Review

Report validated, evidence-backed vulnerabilities. A suspicious pattern is a candidate, not a finding.

## Workflow

1. Resolve scope and authority. Read repository instructions; identify languages, frameworks, entry points, deployments, identities, data stores, secrets, generated/vendor code, and excluded paths.
2. Build a lightweight threat model: assets, attacker capabilities, trust boundaries, privileged operations, security invariants, and likely abuse paths. Use `secure-software-design` instead if the system does not yet exist.
3. Discover candidates across authentication/session recovery, object/function authorization, injection and parsing, SSRF/path/file operations, deserialization, cryptography/key handling, secrets, tenant isolation, races/idempotency, resource exhaustion, logging/privacy, deployment/IaC, and dependency resolution.
4. Trace each candidate end to end: attacker-controlled source or state, transformations and guards, trust-boundary crossings, sink/operation, resulting impact, and relevant runtime/configuration assumptions.
5. Validate before reporting. Search for upstream controls, framework guarantees, canonicalization, authorization, deployment constraints, compensating controls, and counterexamples. Reproduce safely when proportionate and authorized.
6. Calibrate severity from demonstrated impact, exploitability, privileges, exposure, blast radius, detectability, and recovery—not vulnerability names alone.
7. Report findings first, ordered by severity. For each include location, invariant violated, preconditions, exploit path, impact, evidence, minimal remediation direction, verification, confidence, and uncertainty.
8. If the user asked only for review, do not modify files. If fixes are requested, separate validation from implementation and verify the security property plus regressions.

Read [review method](references/review-method.md) for candidate coverage and [report format](references/report-format.md) for findings.

## Guardrails

- Do not claim a dependency is vulnerable from age or package name; use a current authoritative advisory and prove the vulnerable path/version is present.
- Do not expose full live secrets in output. Record location/type and rotate confirmed credentials.
- Do not report missing headers, best practices, theoretical hardening, or unproven “could” scenarios as vulnerabilities.
- Static review cannot prove absence. A clean result must state scope, methods, blind spots, and checks not run.
- Use versioned current standards where helpful; OWASP ASVS 5.0.0 is the stable release verified for this review workflow.
