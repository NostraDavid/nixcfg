# Security review method

## Candidate questions

- **Identity:** enrollment, credential validation, session/token lifecycle, recovery, logout/revocation, fixation, confused deputy.
- **Authorization:** subject/object/action/context on direct, nested, bulk, export, job, websocket, and admin paths; tenant isolation; owner/bypass roles.
- **Input to operation:** canonicalization, injection, templates, commands, queries, paths, URLs, redirects, parsers, deserialization, archives, uploads.
- **Outbound trust:** SSRF, DNS/rebinding, redirect following, credentials forwarded, metadata/control-plane access.
- **State and logic:** replay, idempotency, concurrency, sequence/state transitions, amount/quantity boundaries, duplicate side effects.
- **Resources:** unbounded input, recursion, decompression, allocation, queues, regex, retries, rate/concurrency limits.
- **Secrets/crypto:** generation, storage, exposure, algorithm/protocol use, nonce/key lifecycle, rotation, failure behavior.
- **Supply/deploy:** lockfiles/resolution, build inputs, provenance, CI permissions, artifact mutation, IaC exposure, debug/admin interfaces.
- **Data/privacy:** over-broad reads, logs/errors, retention/deletion gaps, backups and lower environments.

## Validation record

For every candidate record: exact source, transformations, checks, sink/security operation, required configuration, attacker preconditions, counterevidence searched, safe proof or reasoning, impact, and confidence. Discard or label hardening-only candidates whose exploit path is not supported.
