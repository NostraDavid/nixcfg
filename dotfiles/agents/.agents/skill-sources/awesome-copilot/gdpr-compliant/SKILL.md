---
name: gdpr-compliant
description: Apply or review GDPR/AVG data-protection requirements in software and infrastructure handling personal data. Use for data-flow design, minimisation, purpose/legal-basis enforcement, retention/deletion, data-subject rights, processors/transfers, privacy defaults, DPIA triggers, logging, testing data, and privacy engineering reviews. Do not use as a substitute for legal advice or for security work with no personal-data implications.
---

# GDPR Engineering

Translate an accountable processing decision into proportionate technical and organisational controls. Do not invent legal bases, retention periods, or universal technical defaults.

## Workflow

1. Define the processing operation: controller/processor roles, data subjects, data categories and sensitivity, sources, purposes, recipients, systems/locations, transfers, retention, and automated decisions.
2. Obtain the organisation's approved legal basis and necessity assessment for each purpose. Consent is one possible basis, not the default. Escalate missing or ambiguous legal decisions to privacy/legal ownership.
3. Map personal-data flow and copies through APIs, events, logs, analytics, caches, search, backups, support, exports, vendors, CI/test, and deletion/restore paths.
4. Apply purpose limitation and minimisation per field and access path. Remove data not necessary for the stated purpose; constrain collection, processing extent, storage time, and accessibility by default.
5. Design rights handling and identity verification for access, correction, erasure, restriction, objection, portability where applicable, and notification to recipients. Track exceptions and statutory retention without silently promising impossible deletion.
6. Define a justified retention schedule per purpose/category and enforce deletion or effective anonymisation across primary stores and downstream copies. Soft deletion is not erasure; backups need expiry and restore-time deletion replay.
7. Select security measures from the nature, scope, context, state of the art, cost, and likelihood/severity of risks to people. Include access, isolation, resilience, restoration, testing, and incident evidence; do not mandate an algorithm or key size without context.
8. Check processors, sub-processors, data location/transfers, contracts/instructions, telemetry/SDK behavior, and lower environments before data flows.
9. Identify DPIA and consultation triggers, records of processing, notices, consent/objection records, breach workflow, and ownership. High-risk uncertainty requires a DPO/privacy/legal decision gate.
10. Validate controls continuously with data-flow review, authorization and deletion tests, retention evidence, restore exercises, logging inspection, and change review.

Read [engineering checks](references/engineering-checks.md) for implementation questions and evidence.

## Guardrails

- Never declare a system “GDPR compliant” from code alone. State scope, controller decisions supplied, evidence, gaps, and legal/organisational dependencies.
- Personal data can include identifiers, IP/device data, pseudonyms, and linkable combinations. Pseudonymized data remains personal data; anonymization must withstand reasonably likely re-identification.
- GDPR does not require UUIDs, soft deletion, a retention timestamp on every table, one consent model, universal EU-only storage, or fixed retention/cryptographic values.
- Keep book-derived guidance paraphrased; verify law and regulator guidance at time of use. Current anchors checked: GDPR Articles 5, 24, 25, 30–35 and final EDPB Guidelines 4/2019.
