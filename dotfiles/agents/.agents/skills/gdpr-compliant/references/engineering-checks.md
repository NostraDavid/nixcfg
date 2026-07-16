# GDPR engineering checks

## Processing record

Capture purpose, approved legal basis, necessity, data fields/categories, data subjects, source, recipients, controller/processor roles, systems and regions, transfer mechanism, retention and trigger, rights/exceptions, security measures, owners, notice, and DPIA status.

## Data-flow questions

- Which fields are collected, derived, inferred, linked, or exported, and why is each necessary?
- Which identities can access them under which purpose and context?
- Where do logs, traces, analytics, caches, queues, indexes, backups, support tools, and vendors copy them?
- What happens after correction, erasure, restriction, consent withdrawal, objection, account closure, or restore?
- Can a less identifying value, aggregation, on-device processing, shorter precision, or shorter retention satisfy the purpose?

## Evidence

- approved purpose/legal-basis and retention decision;
- data inventory/flow and processor list;
- default settings and authorization tests;
- deletion/correction propagation and restore tests;
- retention job results and exception reconciliation;
- risk assessment/DPIA decisions;
- security and recovery exercises;
- notices, rights workflow, incident/breach ownership;
- current official legal/regulator sources consulted.

## Authoritative anchors

- Regulation (EU) 2016/679 via EUR-Lex.
- European Data Protection Board final guidance, including Guidelines 4/2019 on data protection by design and by default.
- Competent supervisory-authority guidance, such as the CNIL developer guide, while distinguishing guidance from binding law and organisation-specific legal decisions.
