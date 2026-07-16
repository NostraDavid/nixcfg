# Skill library review decisions

This register records human review conclusions. `coverage.json` is the machine-auditable source inventory; temporary extracts and copyrighted book text are not tracked.

## Cluster 1: databases, SQL, and data-intensive architecture

### Database source reviews

| Source                                           | Inspected material                                                                                                                                                | Reusable contribution                                                                                                                                                                 | Decision                                                             |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------- |
| Database Design for Mere Mortals, 2nd ed.        | Full contents and index; preface; complete chapters 4, 11, 13, and 14                                                                                             | Requirements-first seven-phase design process; stakeholder interviews; business rules; final integrity review; separation of logical design from RDBMS implementation                 | Improve `database-design` and `sql-code-review`                      |
| Database Design for Mere Mortals, 3rd ed. sample | Contents, introduction, supplied sample material, and index                                                                                                       | Confirms the later edition retains the requirements, keys, relationships, business-rules, views, and integrity workflow                                                               | Improve `database-design`; use the complete 2nd edition for depth    |
| Database Internals, 1st ed.                      | Preface, audience, scope, part summaries, chapter map, and targeted storage/distribution sections                                                                 | Explains storage engines, B-trees, log-structured storage, replication, consistency, failure detection, and consensus; useful for causal reasoning but not a standalone user workflow | No new skill; support `postgresql-optimization` diagnostics          |
| Fundamentals of Database Systems, 6th ed.        | Contents, complete preface and dependency map; targeted design, normalization, indexing, query-processing, transaction, security, and distributed-system chapters | Broad lifecycle connecting conceptual modeling, relational mapping, normalization, physical design, transactions, recovery, and distributed databases                                 | Improve `database-design`; reference evidence for review boundaries  |
| PostgreSQL High Performance Cookbook             | Contents, preface, and targeted benchmarking, configuration, monitoring, pooling, partitioning, and replication recipes                                           | Start from benchmarking and workload observation; relate server, storage, connection, and replication changes to measurements                                                         | Improve `postgresql-optimization`                                    |
| Refactoring Databases                            | Complete contents; preface; complete chapters 1–5; targeted structural, data-quality, integrity, architectural, and transformation patterns                       | Small ordered changes, regression tests, versioned database assets, compatibility periods, restartable data movement, coordinated application/schema evolution                        | Create `database-refactor`                                           |
| SQL Antipatterns                                 | Contents, introduction, all antipattern summaries, and complete index/design/query pattern sections relevant to review                                            | Review each suspected antipattern through objective, failure, recognition, legitimate exceptions, and contextual remedy; avoid one-size-fits-all findings                             | Improve `sql-code-review`, `database-design`, and `sql-optimization` |
| SQL Cookbook, 2nd ed.                            | Contents, preface, recipe organization, metadata/index chapters, and representative cross-dialect recipes                                                         | Valuable task lookup, but recipes vary by engine and do not form a distinct repeatable skill workflow                                                                                 | No new skill; use as scenario inventory for SQL evals                |
| SQL Performance Explained                        | Complete contents and preface; complete chapters on index anatomy, predicates, joins, sorting/grouping, pagination, DML, and plan reading                         | Explain performance from access paths and measured plans; treat indexes as workload-specific structures with write costs                                                              | Improve `sql-optimization`                                           |
| SQL Queries for Mere Mortals, 4th ed.            | Contents, introduction, relational-structure chapter, set-thinking/join/subquery/grouping maps, and index                                                         | Strong SQL learning progression but no capability gap beyond query formulation and review                                                                                             | No new skill; use for correctness and trigger test cases             |
| SQL and Relational Theory, 3rd ed.               | Contents, all prefaces, chapters on keys, nulls/duplicates, constraints, relational algebra, logic, and SQL departures                                            | Separate model from implementation; preserve predicates, candidate keys, closure, constraints, and set semantics                                                                      | Improve `database-design` and `sql-code-review`                      |
| The Art of PostgreSQL, 2nd ed.                   | Preface, part map, and targeted query-writing, indexing, types, concurrency, and data-modeling sections                                                           | PostgreSQL-specific query and modeling choices belong behind version and workload evidence, not generic feature advocacy                                                              | Improve both PostgreSQL skills                                       |
| The Art of SQL                                   | Contents, preface, and targeted strategy chapters on set-based reasoning, joins, indexing, filtering, and complex-query decomposition                             | Optimize the overall data-access strategy and reduction of work rather than applying isolated syntax tricks                                                                           | Improve `sql-optimization`                                           |

### Skill dossier: `database-design`

- **Intent:** design or substantially redesign a relational schema from domain requirements.
- **Sources:** both editions of _Database Design for Mere Mortals_, _Fundamentals of Database Systems_, _SQL Antipatterns_, and _SQL and Relational Theory_.
- **Existing overlap:** the active Codex-only snapshot mixed design, migration, and optimization and prescribed UUIDs, timestamps, soft deletes, and eventual consistency without requirements.
- **Decision:** replace the active snapshot with a portable shared skill focused on mission, operations, invariants, logical design, evidence-based physical design, and validation.
- **Boundary prompts:** “design a schema for subscriptions” must trigger; “why is this query slow?” and “rename this live column” must not.

### Skill dossier: `database-refactor`

- **Intent:** evolve an existing schema safely across live application versions and existing data.
- **Sources:** _Refactoring Databases_, supported by migration and integrity chapters from the design textbooks.
- **Existing overlap:** `refactor` covers source code and `database-design` covers target models; neither owns schema compatibility, backfills, locks, cutover, or contraction.
- **Decision:** create a separate portable skill using expand/migrate/validate/cutover/contract, with explicit production authorization.
- **Boundary prompts:** “split this populated table without downtime” must trigger; greenfield modeling and isolated query tuning must not.

### Skill dossier: `sql-code-review`

- **Intent:** report evidence-backed correctness, security, integrity, and migration findings in SQL changes.
- **Sources:** _SQL Antipatterns_, _SQL and Relational Theory_, and the design/process textbooks.
- **Problem:** the previous skill mixed tuning with review, treated preferences as defects, assigned numeric scores, and proposed speculative improvements.
- **Decision:** narrow it to actionable findings, dialect discovery, invariant reconstruction, and concrete failing scenarios.

### Skill dossier: `sql-optimization`

- **Intent:** diagnose a measured SQL performance problem across database engines.
- **Sources:** _SQL Performance Explained_, _The Art of SQL_, _SQL Antipatterns_, and representative _SQL Cookbook_ cases.
- **Problem:** the previous skill labeled vendor-specific syntax universal and mechanically preferred joins, `EXISTS`, `UNION ALL`, filtering order, and indexes without plan evidence.
- **Decision:** require engine, plan, workload, baseline, causal hypothesis, controlled change, and before/after measurement.

### Skill dossier: `postgresql-code-review`

- **Intent:** add PostgreSQL semantic, security, DDL, function, trigger, RLS, and migration checks to generic SQL review.
- **Sources:** _The Art of PostgreSQL_, relevant design and antipattern material, and current PostgreSQL documentation.
- **Problem:** the previous skill recommended enums, JSONB, arrays, extensions, regex email checks, and specialized indexes by default.
- **Decision:** make each feature conditional on domain, version, integrity, privilege, and lifecycle requirements.

### Skill dossier: `postgresql-optimization`

- **Intent:** diagnose PostgreSQL query and operational performance with PostgreSQL observability.
- **Sources:** _PostgreSQL High Performance Cookbook_, _The Art of PostgreSQL_, _Database Internals_, _SQL Performance Explained_, and current PostgreSQL documentation.
- **Problem:** the previous skill used obsolete `pg_stat_statements` columns, generic maintenance folklore, and unmeasured performance promises.
- **Decision:** center `pg_stat_statements`, safe `EXPLAIN`, plan estimates, buffers/WAL, waits, vacuum, replication, memory multiplicity, and measured verification.

### Currency checks

PostgreSQL 18 official documentation was checked for concurrent index transaction restrictions and invalid-index cleanup, current `pg_stat_statements` timing columns, identity columns, and the side effects and buffer semantics of `EXPLAIN ANALYZE`.

## Cluster 2: Python, refactoring, debugging, and testing

All 42 sources were checked individually through metadata, contents, preface or introduction, available index/back matter, and targeted workflow chapters. The two image-only programming books were rendered and visually checked. Complete skill-bearing material was read for the scientific-debugging sequence in _Why Programs Fail_ and _Debugging_, the feedback/seam chapters in _Working Effectively with Legacy Code_, the principles and first refactorings in _Refactoring_, and the test-quality/anti-pattern sections in _Unit Testing_.

### Python and software source reviews

| Sources                                                                                                            | Reusable contribution                                                                                                                                   | Decision                                                                                                                                 |
| ------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| _Effective Python_ 1st and 2nd ed.; _Fluent Python_ 2nd ed.; _Robust Python_ early release                         | Python-specific contracts, interfaces, typing, concurrency, robustness, and tests; later editions supersede earlier guidance                            | Use current material to improve `refactor` and `test-design`; no broad Python skill                                                      |
| _High Performance Python_ 3rd ed. early release; _Writing Efficient Programs_                                      | Measure first, profile bottlenecks, reason about representation and algorithmic work                                                                    | No Python-performance skill from an incomplete release and an obsolete language-specific book; reuse in later performance cluster        |
| _Hypermodern Python Tooling_ early release; _The Hacker's Guide to Python_                                         | Packaging, environments, static analysis, testing, documentation, and delivery                                                                          | No change: time-sensitive tooling is already more strictly and currently specified by `python-script-builder` and official documentation |
| _Modern Python Cookbook_; _Programming Python_ 4th ed.; _Python Cookbook_ 3rd ed.                                  | Broad recipes across language, I/O, integration, concurrency, and testing                                                                               | No skill: reference knowledge without one coherent user workflow; older mechanics carry high freshness risk                              |
| _Python Concurrency with asyncio_                                                                                  | Async task lifecycle, cancellation, queues, synchronization, services, and database I/O                                                                 | No separate skill: techniques are valuable but overlap ordinary implementation and debugging; use as concurrency eval material           |
| _Advanced Git_                                                                                                     | Object model, conflicts, rebase, undo, and branching workflows                                                                                          | No skill: repository-wide Git safety policy already supplies the binding workflow                                                        |
| _Code Complete_ 2nd ed.; _Modern Software Engineering_; _The Art of Readable Code_                                 | Change pressure, feedback, naming, responsibility, readable control flow, and verification                                                              | Improve `refactor` and `test-design`; no generic craftsmanship skill                                                                     |
| _Refactoring_ 2nd ed.; _Refactoring to Patterns_ draft                                                             | Behavior-preserving small transformations and conditional use of patterns                                                                               | Improve `refactor`; final edition is primary and the draft is supporting evidence only                                                   |
| _Working Effectively with Legacy Code_                                                                             | Characterization tests, seams, sensing/separation, and dependency-breaking before change                                                                | Improve `refactor`, `refactor-plan`, and `test-design`                                                                                   |
| _The Pragmatic Programmer_ 1st ed.; _Writing Solid Code_                                                           | Broad engineering maxims and defensive C-era examples                                                                                                   | No skill: general theory and dated examples do not justify a distinct workflow                                                           |
| _Debug It!_; _Debugging_; _Effective Debugging_; _The Developer's Guide to Debugging_; _Why Programs Fail_ 2nd ed. | Preserve evidence, reproduce, reduce, trace infection to defect, form falsifiable hypotheses, divide the search, change one variable, and prove the fix | Create `debug-software`                                                                                                                  |
| _Effective Software Testing_; _The Art of Unit Testing_ 2nd ed.; _Unit Testing_                                    | Risk-based selection, test boundaries, observable behavior, doubles, trustworthy oracles, and suite anti-patterns                                       | Create `test-design`                                                                                                                     |
| _Python Testing with pytest_ 1st ed.                                                                               | Concrete fixture, parametrization, marker, and plugin examples                                                                                          | Improve `test-design` only at framework-independent level; current pytest mechanics must come from official docs                         |

### Skill dossier: `debug-software`

- **Intent:** investigate a software failure whose cause is not yet known.
- **Sources:** the five debugging books, with _Why Programs Fail_ and _Debugging_ supplying the causal and experimental backbone.
- **Existing overlap:** `security-review` finds vulnerabilities and `refactor` changes known structure; neither owns reproduction, evidence preservation, hypothesis discrimination, or causal confirmation.
- **Decision:** create a compact evidence-first workflow with a conditional reference for intermittent, concurrent, differential, and reduction techniques.
- **Boundary prompts:** an intermittent crash or corrupt state must trigger; an already-localized fix, generic review, test design, or pure tuning must not.

### Skill dossier: `test-design`

- **Intent:** choose and design a trustworthy portfolio of software tests from risks and contracts.
- **Sources:** all four testing books plus feedback/seam material from the refactoring and Python sources.
- **Existing overlap:** individual implementation skills run tests but no repo-owned skill decides boundaries, oracles, test doubles, case partitions, or residual coverage.
- **Decision:** create a risk-to-boundary workflow; keep framework commands out of the core skill.
- **Boundary prompts:** “design tests for retries and partial failure” must trigger; “run pytest” or “debug this flaky test” must not.

### Skill dossiers: refactoring family

- **`refactor`:** replace the long smell catalog and prescriptive patterns with contract discovery, characterization feedback, named small transformations, seam creation, and semantic diff review.
- **`refactor-plan`:** require repository evidence, preserved contracts, independently safe phases, compatibility, rollback, and explicit decision gates; retain the plan-only stop boundary.
- **`refactor-method-complexity-reduce`:** keep the narrow explicit-metric intent, but prevent metric gaming and require the same analyzer, focused tests, and preservation of evaluation, side-effect, async, and exception order.

## Cluster 3: security, API security, GDPR, and secure delivery

The 11 security books and local OWASP guide were checked individually. The MOBI was converted temporarily and its complete contents plus threat, mitigation, secure-design, review, input, web, and test sections were inspected. Current OWASP ASVS 5.0.0, GDPR Articles 5/24/25/30–35, final EDPB Guidelines 4/2019, the February 2026 EDPB summary, and the CNIL developer guide were used as currency anchors.

- _Building Secure and Reliable Systems_, _Designing Secure Software_, _Secure APIs_, _Secure by Design_, _Security Engineering_, and _Threat Modeling_ justify the new `secure-software-design` workflow.
- _A Bug Hunter's Diary_, _Full Stack Python Security_, _Web Application Security_, the local OWASP guide, and the review portions of the design books improve `security-review`.
- _Securing DevOps_ also feeds `continuous-delivery`; _Python for Offensive PenTest_ is retained only as historical threat material and does not become an offensive skill.
- Computer-ethics material informs stakeholder/harm analysis but does not form an enforceable technical checklist.

### Skill dossier: `secure-software-design`

- **Intent:** design a system or major change around explicit assets, adversaries, trust boundaries, abuse paths, and security invariants before implementation.
- **Overlap:** `security-review` audits existing code; `gdpr-compliant` handles personal-data obligations; neither owns greenfield security architecture.
- **Decision:** create a threat-led design skill with layered control selection, lifecycle review, negative verification, and versioned standards.
- **Boundary prompts:** “design tenant isolation and account recovery” triggers; “scan this repo,” “validate this supplied CVE,” and offensive exploitation do not.

### Skill dossier: `security-review`

- **Problem:** the old skill called itself a scanner, mechanically started with dependencies, used stale package watchlists, treated patterns as findings, always proposed patches, and claimed a clean repository “secure.”
- **Decision:** require scope/threat model, source-to-impact tracing, counterevidence, exploitability validation, contextual severity, review-only immutability, and explicit blind spots.

### Skill dossier: `gdpr-compliant`

- **Problem:** the old skill prescribed UUIDs, soft delete, universal retention periods, consent defaults, algorithms/key sizes, EU-only backups, and table fields as though the GDPR required them.
- **Decision:** make controller-supplied purpose/legal basis, necessity, rights, data flow, justified retention, risk-proportionate Article 32 measures, DPIA/legal gates, and compliance evidence the workflow; explicitly prohibit code-only compliance claims.

## Cluster 4: cloud, GitOps, microservices, SRE, and observability

All 16 sources were reviewed through their value-stream, pipeline, deployment, GitOps, microservice, observability, SLO, overload, recovery, and organisational sections. Argo CD, Kubernetes, command, and platform advice carries a high freshness risk and is not copied into portable skills.

- _Continuous Delivery_, _Continuous Delivery in the Wild_, _Accelerate_, _GitOps and Kubernetes_, _Infrastructure as Code_, _The DevOps Handbook_, and the relevant DZone volume support `continuous-delivery`.
- _Observability Engineering_, _Release It!_, _The Site Reliability Workbook_, and operational microservice/Kubernetes material support `reliability-engineering`.
- Tool-specific guides and broad magazine volumes are recorded as no-skill where their stable contribution is already represented.

### Skill dossier: `continuous-delivery`

- **Intent:** design the verifiable flow from version-controlled change to a safely releasable production state.
- **Overlap:** CI configuration alone is ordinary implementation; `database-refactor` owns live schema evolution; `reliability-engineering` owns service objectives and operating controls.
- **Decision:** create a value-stream, immutable-artifact, compatibility, progressive-release, health-gate, and recovery workflow.

### Skill dossier: `reliability-engineering`

- **Intent:** define or improve SLOs, observability, capacity, overload behavior, resilience, and recovery for a service.
- **Overlap:** `debug-software` investigates a concrete unknown failure and `linux-performance` diagnoses host resources.
- **Decision:** create a user-boundary reliability workflow with explicit SLI contracts, error-budget policy, bounded retries, failure-mode controls, and recovery evidence.

## Cluster 5: statistics, analytics, and forecasting

All 14 books were reviewed, including probability/inference foundations, regression and learning, business framing, data quality, misleading summaries/graphics, and complete time-series model-selection/diagnostic/forecasting chapter maps. _How to Lie with Statistics_ was visually checked because it is image-only.

Decision: no new repo skill. The installed data-analytics plugin already provides focused workflows for data quality, validation, diagnostics, KPI design, business analysis, visualization, and reporting. A second statistical-review or forecasting skill would introduce conflicting triggers. _Data Quality Fundamentals_ contributes stable SLI/ownership ideas to `reliability-engineering`; its early-release mechanics are not authoritative.

## Cluster 6: algorithms, performance, and Linux systems

The five algorithm books were checked for problem formulation, correctness proofs, paradigms, complexity, implementation and performance case studies. They remain high-value general knowledge but do not justify a skill over the model's baseline reasoning.

The six Linux sources were checked individually. Command encyclopedias and systems-programming references remain no-skill; _Systems Performance_ and _BPF Performance Tools_ provide a distinct diagnostic workflow.

### Skill dossier: `linux-performance`

- **Intent:** diagnose a measured Linux process/host regression across CPU, scheduler, memory, storage, filesystem, network, locks, and kernel behavior.
- **Overlap:** SQL/PostgreSQL skills own database plans; `debug-software` owns functional failures; reliability owns service-level objectives.
- **Decision:** create a broad-to-narrow, attribution-first workflow with controlled experiments and explicit warnings about load average, free memory, iowait, `%util`, profiling, tracing, and BPF overhead.

## Cluster 7: architecture patterns, requirements, and formal methods

All eight architecture books and both requirements/formal-methods sources were reviewed. Newer editions are primary; the API sample chapter and draft use-case book are supporting-only. Patterns are retained as conditional solutions with liabilities, not recommendations.

### Skill dossier: `software-architecture-design`

- **Intent:** design or compare system structures from architecturally significant requirements and measurable quality scenarios.
- **Sources:** _Fundamentals of Software Architecture_ 2nd ed., _Designing Data-Intensive Applications_ 2nd ed., _A Philosophy of Software Design_ 2nd ed., and the architecture/pattern catalogs.
- **Overlap:** `database-design` owns relational models, `refactor` owns local structural change, ADR skills record already-made decisions, and codebase onboarding documents current state.
- **Decision:** create a drivers→boundaries/data→alternatives→trade-offs→validation→evolution workflow with an explicit simpler baseline.

### Skill dossier: `create-specification`

- **Sources:** _Writing Effective Use Cases_ and _Specifying Systems_, supported by architecture quality-attribute material.
- **Problem:** the old skill forced `/spec/`, one filename convention, one fixed template, specific .NET test frameworks, coverage targets, and implementation-shaped sections without inspecting repository conventions.
- **Decision:** make specification creation repository-aware and goal/scenario-driven, including actors, stakeholder interests, success/failure paths, measurable quality attributes, invariants, traceable acceptance, and optional formalization only when warranted.

## Cluster 8: computer ethics and systems thinking

_Computer Ethics_ and _Systems Thinking_ were checked for stakeholder, responsibility, boundary, feedback, emergent-behavior, and downstream-consequence perspectives. Both are recorded as no-skill: their value is cross-cutting judgment rather than a bounded, testable workflow, and the repository's binding EU-AI-Act instructions remain the appropriate policy mechanism.
