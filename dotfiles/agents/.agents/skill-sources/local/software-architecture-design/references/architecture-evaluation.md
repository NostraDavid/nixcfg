# Architecture evaluation

## Quality-attribute scenario

Write: **When** `[source]` produces `[stimulus]` under `[environment]`, **the** `[artifact]` shall respond with `[response]`, measured by `[response measure]`.

Examples of measures include tail latency at stated load, maximum data loss, recovery time, blast radius, deployment independence, audit completeness, or time to implement a representative change.

## Alternative matrix

For each alternative capture:

- component and deployment boundaries;
- synchronous and asynchronous dependencies;
- authoritative data owner and consistency model;
- failure propagation and recovery;
- security/trust boundaries and privacy data flow;
- scaling unit and constrained resources;
- observability and operational burden;
- team ownership and cognitive load;
- migration path and reversibility;
- assumptions needing proof.

## Warning signs

- quality attributes without scenarios or measures;
- diagrams without runtime/data/deployment views;
- technology selection before domain and constraint analysis;
- one alternative presented as inevitable;
- distributed transactions or cross-service joins hidden behind APIs;
- events without schema ownership, delivery semantics, idempotency, ordering, and replay policy;
- a “future-proof” abstraction with no identified axis of change.
