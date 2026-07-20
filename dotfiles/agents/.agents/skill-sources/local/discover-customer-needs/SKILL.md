---
name: discover-customer-needs
description: Discover evidence-backed customer and stakeholder needs before choosing or specifying a solution. Use when planning, conducting, or reviewing customer interviews; analyzing interview notes; eliciting product or software requirements; uncovering current workflows, business events, workarounds, constraints, and quality expectations; or choosing between observation, interviews, story mapping, EventStorming, prototypes, and requirements models. Do not use merely to clarify the current user's prompt, write a formal specification, or ask whether people like an already-decided idea.
---

# Discover Customer Needs

Turn scattered statements, feature requests, and observed behavior into a
shared, testable account of the problem. Treat discovery as iterative learning
for a decision, not as transcription or backlog collection.

## Workflow

1. Frame the decision before collecting data:
   - name the decision discovery must inform and who owns it;
   - state the business outcome, target population, current problem, boundary,
     constraints, and known assumptions;
   - identify the three riskiest unknowns and what evidence would change the
     decision.
2. Map the evidence sources. Include affected users, buyers, operators,
   approvers, subject-matter experts, support staff, maintainers, regulators,
   adjacent systems, existing documentation, usage evidence, and people harmed
   by or opposed to the change. Do not let one convenient stakeholder represent
   all user classes.
3. Select the smallest complementary set of discovery techniques that can
   resolve the unknowns. Read [technique
   selection](references/technique-selection.md) before choosing a non-trivial
   mix. Prefer direct observation and existing evidence for actual behavior,
   interviews for motivation and meaning, and collaborative models for
   conflicting or distributed knowledge.
4. Prepare each activity with a learning goal, participant or source, timebox,
   seed artifact, capture method, consent and data-handling needs, and stopping
   condition. Research facts available in the environment before asking people.
   Separate questions that test the problem from questions that evaluate a
   proposed solution.
5. Conduct conversations without manufacturing agreement. Read [interviewing and
   evidence](references/interviewing-and-evidence.md) before interviewing
   someone, drafting an interview guide, or critiquing interview notes. Ask
   about the last concrete occurrence, the current workflow, consequences,
   workarounds, frequency, cost, constraints, and decision path. Listen more
   than speaking and reflect the participant's own terms.
6. Follow the work end to end. Explore the normal path, alternatives,
   exceptions, triggers, outcomes, actors, handoffs, rules, data, external
   systems, and quality trade-offs. When knowledge spans people or a list hides
   sequence, read [collaborative modeling](references/collaborative-modeling.md)
   and use a story map, EventStorming, or a smaller contextual model.
7. Capture observations as evidence, not conclusions. Keep verbatim-enough
   facts, interpretations, assumptions, solution ideas, contradictions, and open
   questions distinguishable. Never turn a feature request directly into a
   requirement; uncover the goal and evidence behind it first.
8. Synthesize across a batch rather than declaring victory after one
   conversation. Segment materially different users, compare sources, weigh
   evidence strength, expose negative cases, and update the initial assumptions.
   Read [synthesis and validation](references/synthesis-and-validation.md)
   before producing findings.
9. Validate the emerging understanding with stakeholders using concrete
   scenarios, walkthroughs, models, counterexamples, measurable fit criteria,
   and the smallest useful prototype. Ask what is wrong, missing, or different
   for another user class; do not seek ceremonial approval.
10. Stop when the named decision has enough evidence, the remaining uncertainty
    is explicit, and the next learning step is cheaper than further discussion.
    Discovery is cyclic; do not imply that all requirements are final.

## Interaction Rules

- During a live interview, ask one focused question at a time and let the answer
  determine the next.
- Use open prompts, then narrow with factual follow-ups. Avoid leading
  questions, stacked questions, generic opinions, future promises, ratings
  without context, and premature solution pitches.
- Treat compliments and uncommitted enthusiasm as weak evidence. Treat observed
  behavior, existing expenditure, repeated workarounds, artifacts, and costly
  commitments as stronger evidence.
- Make conflicts visible. Do not average incompatible accounts or allow
  hierarchy to erase dissent.
- Distinguish customer need, business objective, user task, functional behavior,
  quality expectation, constraint, business rule, and solution idea.
- Do not collect personal or confidential data that the decision does not
  require. Redact it from durable notes when possible.

## Output

Return a discovery brief containing:

1. decision and scope;
2. target segments, stakeholders, and evidence sources;
3. desired outcomes and current workflow;
4. evidence-backed needs, with strength and source diversity;
5. problems, workarounds, consequences, triggers, frequency, and current spend
   or effort;
6. business rules, data, interfaces, quality expectations, constraints, and
   boundaries as relevant;
7. contradictions, assumptions, unknowns, and disconfirming evidence;
8. candidate opportunities kept separate from needs;
9. the smallest next evidence-producing step;
10. traceability from each material conclusion to observations or artifacts.

Hand confirmed needs to `create-specification` only when the user requests a
durable specification. Use `interview-me` instead when the task is solely to
clarify the current user's own request before planning or coding.
