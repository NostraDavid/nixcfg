# Twelve-Factor Review Criteria

Use these criteria to interpret the original methodology during an
evidence-based application review. The canonical source is
[12factor.net](https://12factor.net/), which identifies the text as last updated
in 2017. Preserve the distinction between its original prescription and modern
mechanisms that preserve the same operational intent.

## I. Codebase

**Intent:** Keep one version-controlled codebase for one logical application and
derive multiple deploys from it.

Inspect repository boundaries, deployable units, release provenance, and shared
application code. A monorepo is not itself a violation: identify whether each
independently deployable application has a clear code and release lineage. Look
for copied source, environment-specific branches, hand-maintained production
code, or multiple products deployed from indistinguishable application
definitions.

Strong evidence includes revision identifiers attached to artifacts and deploys,
and the same code lineage across development, staging, and production.

## II. Dependencies

**Intent:** Declare and isolate all application and runtime dependencies.

Inspect manifests, lockfiles, base images, OS packages, external executables,
language runtimes, and build commands. Check whether a clean environment can
reproduce the dependency set without undeclared host tools or globally installed
packages.

Treat a pinned container image, hermetic environment, or declarative system
closure as valid isolation when all required tools are explicit. Flag unpinned
or floating inputs according to their reproducibility impact; do not insist that
every transitive dependency be manually listed when a lock or resolved closure
records it.

## III. Config

**Intent:** Keep values that vary by deploy outside application code and manage
them independently.

Inspect credentials, service handles, hostnames, feature controls,
region-specific values, config defaults, checked-in environment files, and
environment-name conditionals. Apply the source-disclosure test: publishing the
codebase should not disclose credentials.

The canonical method prescribes granular environment variables. Secret stores,
encrypted injection, or mounted configuration can preserve code/config
separation but are modern deviations; mark them `partial` when judging strict
adherence and explain whether the operational intent is satisfied. Do not flag
invariant routing or module wiring merely because it lives in code.

## IV. Backing Services

**Intent:** Treat networked dependencies as replaceable resources attached
through configuration.

Inspect databases, queues, caches, object storage, mail, and third-party APIs.
Verify that resource locators and credentials are externalized and that swapping
an equivalent instance does not require an application code change. Do not claim
interchangeability across incompatible products or schemas; assess detachment
and replacement within the actual contract.

Flag hard-coded endpoints, local/managed branching in business logic, and
lifecycle coupling that prevents resource replacement.

## V. Build, Release, Run

**Intent:** Separate compilation and packaging from release configuration and
runtime execution.

Inspect pipeline stages, artifact identity, configuration injection, migrations,
startup scripts, rollback, and provenance. Prefer immutable, uniquely
identifiable releases and minimal runtime setup. Verify that runtime does not
fetch dependencies, compile assets, mutate shipped code, or silently create a
different artifact.

Strong modern evidence is one immutable artifact promoted between deploys with a
traceable source revision. If each environment rebuilds, determine whether the
outputs remain reproducible before assigning severity.

## VI. Processes

**Intent:** Run the application as stateless, share-nothing processes and store
durable state in backing services.

Inspect local filesystem writes, in-memory sessions, sticky routing, local job
state, caches, uploads, locks, and restart assumptions. Temporary
single-transaction workspace is compatible when correctness does not depend on
its survival.

Flag persistent user data on ephemeral disks, session affinity required for
correctness, and jobs that cannot resume safely on another process.

## VII. Port Binding

**Intent:** Let a network service export itself by binding to a port rather than
relying on an externally injected application server.

Inspect entrypoints, listen addresses, configurable ports, embedded servers,
sidecars, and runtime containers. Reverse proxies and platform routing are
compatible when the application remains self-contained behind them. Framework
hosting models can satisfy the intent when the server dependency and runtime
contract are part of the application package.

Mark `not applicable` for applications that expose no inbound network service.
Do not require HTTP when the application intentionally serves another protocol.

## VIII. Concurrency

**Intent:** Express workload types as managed processes that can scale
horizontally.

Inspect web, worker, scheduler, and consumer process types; replica controls;
partitioning; singleton assumptions; internal daemonization; PID files; and
process-manager ownership. Internal threads or async concurrency are compatible,
but should not be the only path when workload growth requires multiple hosts.

Flag correctness dependencies on one process, unmanaged child daemons, and
workload types that cannot scale independently despite demonstrated demand. Do
not require more than one replica when scale or availability needs do not
justify it; require the architecture not to prevent scaling out.

## IX. Disposability

**Intent:** Support fast startup, graceful shutdown, and recovery from sudden
termination.

Inspect startup duration, readiness, signal handling, termination grace periods,
connection draining, queue acknowledgement, job idempotency, retry behavior,
lock release, and crash recovery. Prefer measured behavior or tests over
declared settings.

Flag dropped or duplicated work, unbounded shutdown, corrupt partial writes, and
startup that performs fragile mutations. Calibrate severity to actual
termination frequency and consequence.

## X. Dev/Prod Parity

**Intent:** Minimize time, personnel, and technology gaps between development
and production.

Inspect deployment frequency, developer operational ownership, artifact
promotion, runtime versions, backing-service types and versions, and environment
provisioning. Similarity matters where differences change behavior; identical
capacity, credentials, datasets, or topology are not required.

Repository evidence rarely proves time and personnel parity. Mark those
dimensions `unknown` unless delivery history or operating practice is available.

## XI. Logs

**Intent:** Emit logs as event streams and let the execution environment route
and retain them.

Inspect stdout and stderr behavior, application-managed log files, rotation,
buffering, sidecar or agent collection, structured events, and
destination-specific SDK coupling. Structured output is compatible. Treat direct
application control of archival, routing, or local rotation as a gap when it
couples the application to its host.

Do not confuse this factor with complete observability: metrics, traces, audit
records, privacy controls, and alert quality are separate concerns.

## XII. Admin Processes

**Intent:** Run one-off maintenance tasks with the same release, configuration,
and dependency environment as regular processes.

Inspect migrations, data repairs, consoles, backfills, and operational scripts.
Verify that code is version-controlled, runs from a specific release, uses the
same dependency closure and config mechanisms, and does not depend on an
operator's unique workstation.

Modern access control, approvals, audit trails, and safe rerun design are
valuable operational controls, but do not present them as original Twelve-Factor
requirements.

## Finding Calibration

Use severity only for actionable gaps:

- **Critical:** demonstrated path to catastrophic loss or broad outage; uncommon
  for a factor review and requires direct evidence.
- **High:** likely material production impact, blocked recovery, credential
  exposure, or architecture that prevents required scaling or safe deployment.
- **Medium:** credible portability, reproducibility, deployment, or operational
  risk under expected conditions.
- **Low:** limited-impact divergence, maintainability friction, or strict
  canonical mismatch whose intent is otherwise preserved.

For every finding, state the observed evidence, the factor expectation, the
consequence in this application, and a proportionate remediation. If the
consequence is speculative, lower confidence or request evidence instead of
inflating severity.
