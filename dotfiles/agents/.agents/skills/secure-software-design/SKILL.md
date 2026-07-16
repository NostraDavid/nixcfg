---
name: secure-software-design
description: Design or substantially revise software security before implementation by modeling assets, actors, trust boundaries, abuse cases, security invariants, and layered controls. Use for security architecture, threat modeling, secure API or identity design, privilege boundaries, and secure-by-design requirements. Do not use for scanning existing code, validating a supplied vulnerability, offensive exploitation, or GDPR-only compliance.
---

# Secure Software Design

Make security a property of the system model and lifecycle, not a checklist added after implementation.

## Workflow

1. Establish scope, business purpose, users/operators, environment, lifecycle, security obligations, and explicitly excluded systems.
2. Inventory assets and harmful outcomes: unauthorized disclosure/change/use, fraud, loss of availability, safety impact, repudiation, privacy harm, and supply-chain compromise.
3. Diagram data/control flow, identities, privileges, entry points, dependencies, trust boundaries, administrative paths, build/deploy path, and recovery path.
4. Describe plausible adversaries by access, capability, incentive, and constraints. Do not design against an abstract omnipotent attacker.
5. Enumerate abuse cases and threat paths across boundaries. Trace preconditions, attacker-controlled input/state, security-relevant operations, impact, and existing controls.
6. Convert material threats into testable security invariants and requirements: authorization subject/object/action/context, state integrity, isolation, authenticity, confidentiality, freshness, audit, recovery, and safe failure.
7. Choose controls in layers, preferring elimination, least privilege, complete mediation, secure defaults, explicit trust, simple state, compartmentalization, and recoverability. Record assumptions and residual risk.
8. Design verification: negative authorization matrices, protocol/state tests, abuse tests, dependency and deployment checks, logging without secrets, incident signals, and recovery exercises. Use a versioned standard such as OWASP ASVS where applicable.
9. Review operational and lifecycle risks: enrollment/recovery, key/secret rotation, migrations, break-glass, tenant administration, decommissioning, and incident containment.
10. Deliver the threat model, prioritized requirements, architecture decisions, verification plan, owners, and unresolved risk acceptances.

Read [threat and control decisions](references/threat-control-decisions.md) for API, identity, and control failure modes.

## Guardrails

- Authentication does not imply authorization; encryption does not establish endpoint trust or data integrity by itself.
- IDs, hidden endpoints, client validation, CORS, or network location are not authorization controls.
- Avoid custom cryptographic protocols and universal algorithm parameters; use maintained constructions and current official guidance.
- Do not claim compliance or “secure” status from a checklist. Scope, version, evidence, and residual risk are required.
