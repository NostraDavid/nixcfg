# Technique Selection

Choose techniques from the information gap and evidence source, not from habit.
Most meaningful discovery needs more than one technique because people,
artifacts, systems, and observed work reveal different facts.

## Contents

- [Selection Matrix](#selection-matrix)
- [Interviews](#interviews)
- [Observation and Apprenticing](#observation-and-apprenticing)
- [Workshops](#workshops)
- [Existing Evidence](#existing-evidence)
- [Model Selection by Gap](#model-selection-by-gap)
- [Triangulation](#triangulation)

## Selection Matrix

| Unknown or condition                                       | Primary technique                                        | Complement                                    | Main caution                                                |
| ---------------------------------------------------------- | -------------------------------------------------------- | --------------------------------------------- | ----------------------------------------------------------- |
| Motivation, meaning, goals, consequences                   | Individual interview                                     | Recent artifact or observation                | Self-report can describe an idealized process.              |
| Tacit, repetitive, physical, or tool-mediated work         | Observation or apprenticing                              | Short contextual interview                    | Observation is costly and can change behavior.              |
| Conflicting accounts across roles or silos                 | Facilitated workshop                                     | Prior interviews and seed model               | Hierarchy and groupthink can hide dissent.                  |
| Large, dispersed population with known answer choices      | Survey                                                   | Exploratory interviews first                  | A survey scales the researcher's assumptions.               |
| Existing or replacement system                             | Document, interface, UI, support-log, and usage analysis | Observation and interviews                    | Existing behavior may be accidental or obsolete.            |
| End-to-end user journey and release slicing                | Story mapping                                            | Research on present behavior                  | A future map can turn assumptions into backlog.             |
| Cross-silo domain behavior, responsibilities, and unknowns | Big Picture EventStorming                                | Follow-up interviews or focused modeling      | It is a learning model, not a finished specification.       |
| One interaction with alternatives and failures             | Scenario or use case                                     | Observation and acceptance examples           | Do not model only the happy path.                           |
| Boundary, actors, adjacent systems, and flows              | Context diagram or ecosystem map                         | Interface analysis                            | A context picture does not explain internal behavior.       |
| External triggers and required responses                   | Event-response analysis                                  | Scenarios or EventStorming                    | Include temporal and failure triggers, not only users.      |
| Business concepts, relationships, and ownership            | Conceptual data model and glossary                       | Real forms, payloads, and reports             | Do not jump to a physical database schema.                  |
| Complex policy or combinations of conditions               | Decision table or tree                                   | Concrete examples                             | Confirm completeness, overlap, and impossible combinations. |
| Lifecycle and allowed transitions                          | State table or diagram                                   | Event scenarios                               | Define invalid and terminal transitions too.                |
| Unclear interaction or feasibility                         | Low-fidelity prototype or technical spike                | Task-based evaluation                         | Label the prototype's question and planned fate.            |
| Quality expectation such as reliability or latency         | Quality-attribute scenario                               | Operational evidence and trade-off discussion | Avoid adjectives without stimulus, response, and measure.   |

## Interviews

Use interviews when a participant has relevant experience, meaning, incentives,
or decision knowledge. They are easy to schedule and suitable for sensitive
subjects or time-poor experts. Do not use them as the only source when knowledge
is tacit, fragmented, political, or contradicted by actual behavior.

Interview different user classes separately when power or goals differ. A buyer,
operator, end user, support engineer, administrator, and regulator should not be
assumed to share needs. Use a small-group interview only when participants can
safely correct each other.

## Observation and Apprenticing

Use observation when the sequence, tools, interruptions, exceptions, and
unofficial workarounds matter. Ask the participant to teach the work while doing
it when interruption is safe. Capture what enters and leaves each step,
decisions made, waiting, rework, handoffs, and environmental constraints.

Sample representative and edge cases. One polished demonstration can hide
variation. Do not record screens, voices, people, or sensitive artifacts without
explicit permission and an actual need.

## Workshops

Use workshops to create shared understanding, resolve disagreements, and work
across distributed knowledge. Prepare a goal, agenda, seed material, roles,
ground rules, timeboxes, and parking lot. Include knowledge, consequences, and
decision authority while keeping the active group small enough to work. Separate
facilitation, participation, and capture when possible.

Use prior interviews or analysis to avoid beginning with a blank surface. Make
disagreement visible, invite quieter perspectives, and focus criticism on the
model. A workshop produces evidence and open issues; attendance does not equal
consent or completeness.

## Existing Evidence

Inspect policies, contracts, regulations, process documentation, tickets,
support cases, analytics, audit logs, forms, reports, interfaces, and current
UI. Existing sources reveal information that people forget to mention and reduce
interview time. For each source, record provenance, date, owner, intended
process, observed freshness, and whether actual behavior agrees.

Existing systems are evidence of current behavior, not proof of current need.
Ask which constraints are still binding and which practices are legacy
accidents.

## Model Selection by Gap

Select the smallest model that makes the missing relationship discussable:

- value and purpose: outcome map, objective chain, or measurable success model;
- people and permissions: stakeholder map, organization map, or
  roles-permissions matrix;
- work: story map, process flow, scenario, or use case;
- surrounding systems: context diagram, ecosystem map, or interface table;
- information: conceptual data model, data flow, dictionary, or report
  definition;
- policy: business-rule catalog, decision table, or decision tree;
- lifecycle: state table or state diagram;
- quality: stimulus-context-response-measure scenario.

Choose from project characteristics too. Replacement projects require
present-state evidence and preserved outcomes; large ecosystems require
interface and flow models; analytics work requires data, decision, and report
models; real-time systems require event, state, and timing models; internal
systems often require roles, permissions, process, and adoption evidence.

Do not create every model. A model earns its cost when it exposes an unknown,
aligns conflicting views, supports a decision, or supplies verifiable criteria.
Tailor notation only when the audience cannot otherwise understand the needed
information, and explain the notation visibly.

## Triangulation

Combine methods deliberately:

- interview + observation checks stated work against actual work;
- document analysis + interview separates policy from practice;
- interviews + workshop brings private perspectives into shared reconciliation;
- story map + prototype tests a selected journey;
- EventStorming + context or data model clarifies boundaries and information;
- quality scenario + operational data tests whether a threshold is necessary and
  realistic.

Stop adding techniques when new evidence no longer changes the decision, model,
segments, or known unknowns enough to justify its cost.
