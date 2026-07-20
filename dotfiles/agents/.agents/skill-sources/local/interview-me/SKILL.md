---
name: interview-me
description: Extract the current user's real intent before planning, specifying, or coding. Use when their request is underspecified or missing who it is for, why it matters, what observable success means, or which constraint binds; or when the user asks to be interviewed, grilled, or have their own thinking stress-tested. Do not use for clear mechanical requests, non-interactive runs, or research interviews with customers or multiple stakeholders.
---

# Interview Me

Find the gap between what the user asked for and what they actually need before
switching costs exist. Deliver a confirmed statement of intent, not a plan or
implementation.

## Interview Loop

1. Inspect available repository and conversation evidence first. Do not ask the
   user for discoverable facts.
2. State a one-sentence hypothesis of the user's intent and an honest confidence
   percentage. Below 70%, name the most consequential missing information.
3. Ask exactly one focused question at a time. Ask for a recent concrete example
   when the request is abstract: what happened, who was affected, what they did
   instead, and what consequence prompted the request. Let each answer determine
   the next question.
4. Keep the question neutral. Do not embed the hoped-for answer, seek approval
   of your hypothesis, or rely on hypotheticals about future behavior. State a
   best guess separately only when it helps the user correct you.
5. Follow proposed features or methods back to the underlying outcome.
   Distinguish a binding need from a preference by asking what fails without it,
   what trade-off the user would accept, and how success would be observed.
6. Reflect the user's own terms and ask them to correct material
   interpretations. Treat vague words such as "scalable", "clean", "modern",
   "easy", and "fast" as unresolved until tied to a scenario and observable
   threshold.
7. Surface contradictions directly and allow silence. Do not fill gaps with
   invented stakeholder answers or raise confidence merely because the user
   agrees politely.
8. Stop around 95% confidence, when remaining answers are predictable and would
   not change the outcome, beneficiary, success measure, binding constraint, or
   scope.

## Confirm Intent

Restate the result in five to eight concise lines:

- Outcome
- User or beneficiary
- Why now, including the triggering example
- Observable success
- Binding constraint or trade-off
- In scope
- Out of scope
- Remaining assumption, if any

Ask the user to confirm or refine the statement. Require meaningful confirmation
before downstream planning, specification, or implementation. If the user
delegates a material decision back, present two concrete choices, recommend one
with evidence, and ask them to select or correct it.

Do not batch questions, produce a premature plan, save an intent artifact
without permission, or turn the exchange into customer research. Use
`discover-customer-needs` for interview guides, customer or stakeholder
conversations, multi-source elicitation, and analysis of discovery evidence.
