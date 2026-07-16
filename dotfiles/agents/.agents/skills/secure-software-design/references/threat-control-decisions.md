# Threat and control decisions

## Threat record

Capture asset/harm, actor and access, entry point, trust boundary, preconditions, attacker-controlled data or state, path to impact, current controls, evidence, severity rationale, proposed invariant/control, verification, owner, and residual risk.

## Identity and API questions

- How is identity enrolled, authenticated, linked, recovered, suspended, and revoked?
- What authenticates the client/server and prevents replay or confused-deputy behavior?
- Is authorization evaluated for every object and action after server-side canonicalization?
- Can bulk, nested, search, export, websocket, job, and administrative paths bypass the same invariant?
- Are idempotency, rate/size limits, pagination, resource exhaustion, and partial failure defined?
- Can one tenant influence identifiers, caches, queues, logs, or keys used by another?

## Control failure modes

- fail-open behavior when policy/configuration/identity is missing;
- shared privileged identities and ambient authority;
- unbounded retries, parsers, decompression, or allocation;
- mutable audit records or logs containing credentials/personal data;
- security checks only in the UI or API gateway;
- owner/admin/service roles that bypass row/object policy unexpectedly;
- recovery weaker than normal authentication;
- old application versions, jobs, tokens, or data formats surviving a migration.
