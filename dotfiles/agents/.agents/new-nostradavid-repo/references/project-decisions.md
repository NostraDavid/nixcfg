# Project decisions

Classify every numbered area in `docs/project-baseline.md`. Apply its rules when
the capability exists. For an inapplicable or deferred area, state the reason
and what would make it relevant. Create infrastructure only for an actual
project capability. Preserve explicit user choices over these defaults.

## 1. Language, programs, and libraries

Use Python by default when the project has no selected language. Prefer uv,
typed boundaries, Ruff, ty, and focused pytest tests. Choose compatible pinned
versions from the actual environment. Keep all project-owned programs,
libraries, tests, infrastructure configuration, and docs in one repository.
Create separate packages when they have real ownership or reuse boundaries.

Extract duplicated behavior into its owning library. Reusable API, domain,
persistence, messaging, and integration logic belongs in libraries; executable
programs handle transport and orchestration. Keep dependency direction explicit.
Delay a detailed domain model until source behavior and use cases establish it.

## 2. Local runtime and state

Use Nix for native software, one `./dev` lifecycle controller when needed, and
Just as the developer-facing interface. Define the component dependency graph
and process ownership. Libraries are imported code, not supervised components.
New infrastructure and end-to-end workflows join this same command interface.

Keep application runtime state under ignored `./var/`: databases, data,
generated configuration, logs, and secrets. Language-tool environments may use
their conventional ignored directories. Support inspection and repeatable setup.
Restrict secrets to owner-only directories and files.

Local startup should work without production credentials or a mandatory secret
manager. Generate disposable development credentials only when needed. Store
generated values under `var/secrets/generated/` and explicitly supplied external
credentials under a separate protected area. Redact values from output and
expose references or availability status. Never silently activate live API use.

## 3. Lifecycle, health, and recovery

Reload or restart the affected component after a source change. Exclude state,
dependency, cache, and build trees from watching. Keep full-runtime restart an
explicit operation. Identify owned processes reliably, send a graceful stop,
wait for exit, and escalate only for that owned instance.

Separate startup, readiness, and liveness. Wait for startup/readiness before
declaring a component usable. A readiness failure alone should not restart a
healthy process. Bound startup time, recovery attempts, and backoff. Report a
failed recovery clearly and retain useful evidence.

## 4. Operational observability

For services and background jobs, use structured JSON events with UTC time,
severity, service/component, environment, event name, and correlation IDs. Carry
trace/span IDs when tracing exists. Keep command results on stdout and
diagnostics on stderr. Do not require a telemetry stack for a trivial CLI.

Use bounded metric labels and explicit units for health, throughput, latency,
queue lag, error rates, resource usage, and recovery. Use OpenTelemetry for
traces when needed, with a local collector/viewer and scrape-based metrics such
as Prometheus when the runtime needs them. Validate configuration and alert
rules, including representative rule tests, through Just quality gates.

Bound managed service logs. A local starting policy is 10 MiB per active stream
with three rotated segments, mode `0600`, and compression of closed segments.
Preserve schema-versioned, allowlisted event fields. Keep unstructured native
logs bounded and separate when they remain necessary for diagnosis. Operational
logs, durable provenance, and security audit trails have different retention.

Measure memory, CPU, I/O, latency, throughput, compression, and concurrency on
resource-sensitive paths. Explain and bound amplification. Use bounded synthetic
benchmarks instead of live side effects or an arbitrary performance claim.

## 5. Relational persistence

For Python relational applications, prefer SQLAlchemy 2 and Alembic. A fresh
database must be reconstructible from versioned migrations. Keep migration
history, transaction boundaries, constraints, concurrency, and persistence
ownership explicit. Repeating an already-applied migration must be safe.

Expose status, migration, and explicit reset/recovery through the project
interface. Treat reset and destructive migration as separate, authorized
operations. Choose backup, restore, and recovery requirements explicitly.
Reingestion instead of backup is an owner-approved development tradeoff only
when sources and acceptable loss/recovery time are understood. Never infer that
a new repository permits data loss.

## 6. API and message contracts

Use typed request, response, and error models. Keep HTTP interface contracts in
OpenAPI and data/message schemas in an appropriate versioned schema format.
Prefer link relations for related resources and available transitions where
HATEOAS fits the API; record an exception when it does not. Use UUIDv7 for
internal identifiers where supported and preserve external identity formats.

Define compatibility, ownership, pagination, error handling, and version support
before changing a public boundary. Preserve supported old versions and make
breaking changes explicit. Keep mechanical schemas generated from authoritative
types where possible. Test the actual runtime against the declared contract.

## 7. Data layers and provenance

For ingestion projects, separate Raw, Canonical, Normalized, and Curated roles.
Retain the decoded response body without parsing or transformation, with
compression and sidecar metadata; do not rewrite them to correct source content.
Canonical changes representation, Normalized standardizes fields/types/time, and
Curated provides consumer-ready projections. Rebuild downstream layers without
modifying upstream observations.

Retain Raw evidence while it exists; normal derived-data cleanup must not remove
it. Identify logical records, source observations, and produced artifacts
separately. Record source/request scope, input/output checksums, schema and
contract identity, transformation/code revision, run identity, and quality
status. Publish atomically with durable evidence so a crash cannot advertise
partial work.

Validate the properties owned by each layer: transport and checksums, source
structure, normalized consistency, then domain invariants. Record schema
fingerprints and classify compatible versus breaking drift. Quarantine invalid
observations, retain corrections, and expose quality, availability, coverage,
and freshness separately. Declare numeric precision and scale; preserve exact
source decimals instead of converting them to binary floating point. A
successful job alone does not prove complete data. Allow an explicit
newest-valid fallback for the same scope, marked stale; never hide a missing
scope behind unrelated data.

Use ODCS for dataset contracts and ODPS for consumer-facing data products when
these boundaries exist. Pin schema versions, validate locally, check references
and runtime agreement, and maintain owner/meaning/limitations. A partition or
dataset is not automatically a separate product. Keep measured lineage and
quality outcomes in their stores rather than mutable descriptor files.

## 8. Orchestration, messaging, and retry semantics

Choose one authoritative orchestration control plane. For a Python data
pipeline, prefer Dagster assets, partitions, schedules/sensors, run queues,
backfills, cancellation, and selective rebuilds. Keep `./dev` responsible for
process lifecycle, not a second scheduler. Workers execute bounded units and
must not independently plan the same work. A message bus is optional.

When messaging is required, assume at-least-once delivery. Define logical
identity, idempotent consumers, durable deduplication, ordering scope, and
acknowledgement after durable processing. Bound retries and quarantine poison
work with an explicit replay path. Avoid an end-to-end exactly-once claim.

Use Stamina for Python transient-operation retries when retries are needed.
Bound elapsed time, attempts or admission budget, and concurrency. Honor rate
limits, cooldown, and backpressure. Validation and authentication errors need
correction instead of blind retries. Persist recovery state; repeating a job
must not produce unbounded duplicates.

## 9. Source discovery and temporal ingestion

Discover real endpoint semantics, retained history, pagination, time precision,
rate costs, auth scope, sparse responses, and revision behavior before fixing
the domain model or enabling sustained ingestion. Keep unknown choices deferred
with an explicit exit criterion; use a bounded manual probe in the meantime.

Represent timestamps as timezone-aware UTC and serialize them as RFC 3339.
Distinguish event time, observation time, and processing/publication time. Use
monotonic time for local duration measurement. Define interval boundaries and
precision explicitly; freeze historical campaign cutoffs across retries.

Use bounded half-open windows and closed intervals for finalized period-based
outputs. Retain source corrections and do not invent missing rows or zero-valued
observations. Keep intraday and aggregate products compatible or expose an
additive contract. Coalesce missed work rather than queuing every missed tick.
Establish bounded metadata lookup and artifact selection before high-frequency
operation; compression does not remove file-count or indexing costs.

Declare the initial priority scope and the evidence required before broader work
is admitted. Share provider admission and cooldown across all workers. Prefer
anonymous access for public data where supported; credentials may enter a
fallback pool only with explicit consent and the provider's rules. Private
owner-derived signals require opt-in, ownership isolation, revocation/deletion,
and a non-starving scheduling policy. Never invent source-history completeness
or authorize a bulk capture from a design decision alone.

## 10. Identity, security, and privacy

Keep local services loopback-bound by default. Document any internal-network
assumptions as development constraints. Require explicit authentication and
authorization when identities or private data exist; network location alone is
not authorization. OIDC/Keycloak is an available service-login pattern, not a
mandatory dependency of every repository.

Validate token issuer, audience, signature, expiry, and identity claims.
Separate user and service identities. Enforce owner-scoped access to private
records, credentials, caches, and derived observations. Bound request size,
pagination, concurrency, and expensive queries. Redact secrets and sensitive
data in telemetry; keep private responses out of shared caches.

Classify confidentiality, integrity, and availability independently of storage
layer. Decide visibility, retention, erasure, audit ownership, and incident
response for personal/private data. Preserve immutable public source evidence
without treating immutability as permission to retain personal data forever.
Make production exposure, stronger secret management, and broader access
separate decisions.

## 11. Operations and delivery

Document applicable procedures in `docs/runbooks/`: evidence to inspect, scoped
commands, preconditions, recovery verification, and escalation. Cover
startup/shutdown, failed readiness, restart loops, migrations, retries,
quarantine/replay, data rebuilds, credential handling, and resource saturation
only where those capabilities exist. Keep procedures aligned with Just/dev.

Use the Git commit as application release identity and generate changelogs from
the previous deployed baseline. Keep protocol/data compatibility versions
separate. During local development, defer deployment/promotion machinery and
published artifacts until the user actually needs them. Record the trigger for
revisiting that choice before shared or production use. Language-required local
compilation and third-party dependency caches remain normal development work.
