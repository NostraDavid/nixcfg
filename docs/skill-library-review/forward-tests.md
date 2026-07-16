# Forward-test results

The committed `evals/` directories are the fixed train/validation corpora. This
file records representative clean-context task runs; it contains conclusions and
assertion outcomes, not full generated answers.

## Database and SQL family

| Task                                           | Skills under test         | Result                                                                                                                                                                     |
| ---------------------------------------------- | ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Multi-tenant billing design                    | `database-design`         | Passed requirements, invariants, history, constraints, concurrency, and validation assertions; avoided unconditional UUID/soft-delete/partition defaults                   |
| 180M-row live relationship migration           | `database-refactor`       | Passed expand/migrate/validate/cutover/contract, mixed-version compatibility, consumer inventory, bounded backfill, replica guardrails, and recovery assertions            |
| Join-multiplication query regression           | `sql-optimization`        | Treated rewrite as a hypothesis, preserved semantics, required plan/workload evidence, and made index candidates conditional                                               |
| Rolling `tenant_id NOT NULL` migration review  | `sql-code-review`         | Found old-writer incompatibility, ambiguous mappings, race windows, unbounded backfill, and DDL-lock risks as concrete invariant failures                                  |
| PostgreSQL RLS with pooled GUC state           | `postgresql-code-review`  | Found session leakage and owner bypass, distinguished a shared-GUC trust limitation, and correctly noted that `USING` is implicit `WITH CHECK` for an `ALL` policy         |
| PostgreSQL 18 read regression during backfill  | `postgresql-optimization` | Separated plan/cache/I/O/WAL/vacuum/replica/application hypotheses, used `EXPLAIN` safely, proposed reversible experiments, and rejected an unsupported index prescription |
| Six neighboring trigger prompts plus negatives | all six                   | Each prompt selected one unique skill; conceptual teaching, fixture generation, and visualization selected none                                                            |

The previous versions were compared on their written decision rules and
assertions: they prescribed feature/index/query choices, mixed
design/review/tuning, used obsolete PostgreSQL statistics, and lacked
live-schema compatibility. The new task outputs did not reproduce those
failures.

## Debugging, testing, refactoring, and specifications

A clean agent selected exactly one of `linux-performance`, `debug-software`,
`test-design`, `refactor`, `refactor-plan`, `refactor-method-complexity-reduce`,
and `create-specification` for seven close prompts. The Linux task remained
hypothesis-driven and explicitly stated that no diagnosis was verified. The
specification task inspected repository conventions, found no product-spec
convention, labeled proposed numeric values, covered state/failure/concurrency,
and exposed open stakeholder decisions.

The no-skill baseline chose similar broad workflows, but did not inspect the
repository or explicitly separate placement/ownership facts from illustrative
specification content. The skill-assisted output therefore added repository
grounding and stronger verification boundaries with small prompt-context cost;
the skills themselves remain 26–43 lines plus one conditional reference.

## Architecture, delivery, and reliability

Both clean runs rejected a 12-microservice/shared-database/Kafka proposal for a
six-person team and recommended a smaller modular/cell baseline. The
skill-assisted run additionally:

- expressed tenant isolation and corruption as invariants rather than consumable
  error budgets;
- separated provisional numerical hypotheses from approved SLOs and refused to
  claim the p99/RTO/RPO targets were proven;
- assigned authoritative data owners and detailed idempotency, ordering, replay,
  mixed-version, artifact, and forward-recovery semantics;
- tied canary gates to concurrent controls, minimum evidence, overload,
  reconciliation, and recovery experiments.

All assertions passed except “prove final targets achievable,” which correctly
failed because no forecast, baseline, dependency evidence, or experiment result
was supplied. This is a desirable refusal, not a skill regression. Output was
more detailed than the baseline; users asking for a brief assessment may need an
explicit brevity constraint, while the skill prompt overhead stays compact.

## Security design, security review, and GDPR engineering

The skill-assisted clean run separated greenfield threat design, validated
review findings, and privacy-engineering decisions. It reported the explicit
corporate-network trust and request-body logging defects, but kept
client-supplied tenant ID as an unvalidated candidate until server binding could
be inspected. It treated hashed email as pseudonymous, mapped
derived/vendor/backup copies, covered rights and restore-time deletion replay,
and made no legal-basis, fixed-retention, or compliance claim.

The no-skill baseline was generally useful but immediately labeled client tenant
IDs “Critical” without establishing missing server-side binding, assigned
several severities to unspecified controls, and described indefinite backups as
conflicting with any future deletion rule before establishing approved purposes
or legal exceptions. The revised skills therefore materially reduced
false-positive and compliance-claim risk.

## Acceptance

- Trigger uniqueness: passed for all tested neighboring families.
- Book-derived assertions: passed, with the one explicit unprovable-target
  refusal above.
- No-skill comparison: material improvement for security/privacy and
  repository-aware specification; moderate but concrete consistency gains for
  architecture/delivery/reliability.
- Previous-version comparison: database, SQL, PostgreSQL, refactor, security,
  GDPR, and specification failure modes removed from the active instructions.
- Context cost: every changed `SKILL.md` is 26–57 lines; conditional depth is
  one reference level.
