# Forward evaluation: draft cache decision

Request: Schrijf met $adr een concept voor een cachekeuze. Domein SYS, systeem
Catalog. We twijfelen tussen geen cache en een gedeelde cache. Latency lijkt een
probleem maar is niet gemeten; eigenaar, goedkeurder en besluitdatum zijn
onbekend. Maak nu een bruikbaar concept.

## Actual behavior

- Read SKILL.md, assets/adr-template.md and references/format.md without reading
  eval assertions.
- Produced ADR-SYS-0001-cachekeuze-catalog.md immediately without clarification.
- Kept status DRAFT and chosen option Undecided.
- Used TODO owner and decider, null decision/review dates, system Catalog and
  domain SYS.
- Compared Geen cache and Gedeelde cache, with conditional trade-offs and
  explicit absence of measurements.
- Proposed measurements and acceptance criteria as next steps without
  fabricating results, people, approval or numerical targets.
- Marked proposed participant roles and driver weights as unconfirmed.
- Scoped numbering to the new isolated evaluation directory; no production
  collection or history was inspected.

## Validation

Attempted from the skill directory:

```sh
./scripts/validate_adrs.py validate evals/results/draft-cache --format json
```

Pending: LeanCTX ctx_shell blocked execution because validate_adrs.py is not in
its command allowlist. No validator result was obtained; no alternate route or
configuration change was attempted.

Manual review found the required metadata, section order, matching option names
and three consequence categories present. This is not a structural validator
pass.

## Usability observations

The workflow allowed useful progress despite missing decision evidence and named
responsibilities. The format explicitly permits Undecided, avoiding an
unsupported recommendation.

Minor friction: SKILL.md step 4 says to state the chosen option and explain why
alternatives lost, while the format contract permits an unresolved draft; a
reader must reconcile these by leaving selection and rejection open. Consider
making the draft exception explicit in step 4.

The mandatory Neutral observations in each option encourage weak filler for this
scenario. Explicitly stating no known neutral effect is available, but the
template still steers toward a Neutral because phrase. English parser headings
mixed with Dutch prose are intentional and clearly documented.

The skill's direct executable validation command conflicts with this
environment's LeanCTX allowlist; an authorized validation route is needed before
claiming a pass.
