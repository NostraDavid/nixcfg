# Collaborative Modeling

Use collaborative modeling to build shared understanding, not to decorate
conclusions already made. Keep artifacts movable, visible, and deliberately
incomplete. Write first, explain while pointing, then place the item where
everyone can challenge or move it.

## Story Mapping

Use a story map when sequence and the whole user experience are being lost in a
flat backlog.

1. Frame the map with the business outcome, target customer or user, situation,
   and success measure.
2. Tell one concrete user's story from trigger to outcome. Place major
   activities left to right.
3. Add user tasks beneath each activity in narrative order. Put variants and
   detail lower, not merely lower-priority feature ideas.
4. Walk the map aloud. Add setup, handoffs, feedback, administration, failure
   recovery, and effects on other actors that the initial story skipped.
5. Test different examples: simplest typical case, consequential exception, and
   a difficult boundary case. Mark assumptions and evidence gaps on the map.
6. Distill a stable backbone only after the story is understood. The backbone is
   an orientation aid, not the product architecture.
7. Slice horizontally around a specific outcome, population, and learning goal.
   Preserve an end-to-end usable journey; do not call a collection of
   disconnected easy features a minimum viable release.
8. Name what each later slice is expected to improve or learn. Re-plan after
   evidence from the first release rather than treating lower slices as
   promises.

Prioritize outcomes, then target users and their goals, then tasks or features.
The map is a memory and conversation aid, not a substitute for research,
acceptance examples, or a specification.

## Big Picture EventStorming

Use Big Picture EventStorming when domain knowledge crosses silos and the team
needs to expose the business flow, boundaries, responsibilities, risks, and
disagreement.

### Prepare

- Invite a diverse mix of people with relevant expertise, curiosity,
  consequences, and decision power.
- Provide a very large continuous modeling surface, room to move, one working
  marker per participant, plentiful sticky notes, a visible legend, timer,
  breaks, food, and accessible seating.
- Assign a facilitator and capture role. Explain the purpose and expected
  discomfort briefly; introduce notation incrementally.

### Explore

1. Ask everyone in parallel to write domain-relevant events in past tense on
   orange notes. Start from anywhere; guesses and duplicates are welcome.
2. Let locally ordered clusters emerge before forcing consensus. Break up
   committees that try to perfect every note before placing it.
3. Arrange events into a rough left-to-right timeline. Walk the narrative and
   use contradictions to trigger explanation.
4. Mark risks, disagreements, confusion, bottlenecks, and missing knowledge as
   visible hot spots.
5. Add people, departments, external systems, policies, commands, information,
   or value only when the current plateau calls for that distinction. Keep a
   visible legend.
6. Revisit the flow from different perspectives: customer value, delay, money,
   failure, compliance, responsibility, and desired future state.
7. Select the most consequential hot spots for follow-up. Do not attempt to
   solve or formalize the entire domain in one session.

The facilitator protects participation and learning. Avoid supplying the domain
answer, enforcing precision too early, letting hierarchy dominate, or silently
cleaning contradictions from the artifact. The result represents current
collective understanding, including known unknowns; it is not executable design
or an approved specification.

## Smaller Models

Use a smaller model when one relationship is unclear:

- context diagram: target system, direct actors/systems, and labeled flows;
- ecosystem map: wider systems landscape and upstream/downstream effects;
- event-response list: external, temporal, and failure triggers with required
  responses;
- scenario: actor, trigger, goal, normal steps, alternatives, exceptions, and
  outcome;
- conceptual data model: business concepts, identity, relationships, ownership,
  and lifecycle;
- decision table: conditions, actions, overlaps, gaps, and impossible
  combinations;
- state table: states, events, guards, transitions, side effects, and invalid
  transitions;
- quality scenario: source, stimulus, operating context, affected artifact,
  response, and measure.

Walk each model with the people who supplied its knowledge. Ask them to change
it directly. Validate with at least one ordinary example, one failure, and one
boundary case. Keep unresolved items visible instead of inventing connective
detail.
