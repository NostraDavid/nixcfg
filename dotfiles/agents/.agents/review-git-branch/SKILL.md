---
name: review-git-branch
description: "Review branch or PR changes against the base branch for correctness, security, scalability, tests, and merge readiness. Exclude specialized security, API-schema, performance-only, Twelve-Factor, and architecture-only reviews."
---

# PR Review

Voer de review read-only uit. Baseer alle claims op de output van
`~/.agents/skills/review-git-branch/scripts/branch-compare.sh`, de repository-instructies en controleerbare bron-
of test-evidence.

## Workflow

1. Bepaal de repository-root en voer het gebundelde script uit:

   `bash ~/.agents/skills/review-git-branch/scripts/branch-compare.sh --repo <repository-root>`

   Gebruik `--base <git-ref>` wanneer de gebruiker een base noemt. Het script
   geeft één Markdown-rapport met base, merge-base, commits, diff-stat,
   gewijzigde paden, diff-checks en patch. Gebruik dat rapport als primaire
   diff-input; voer geen alternatieve branch-heuristiek uit.
2. Als het script faalt of geen niet-lege diff oplevert, maak geen inhoudelijke
   review. Meld de fout en vraag om een expliciete base-ref wanneer nodig.
3. Lees toepasselijke `AGENTS.md`-, `README`-, CI- en testinstructies voordat
   je conclusies trekt. Inspecteer de gewijzigde files en relevante context.
   Beantwoord de vijf vragen hieronder voor de gewijzigde code die data verwerkt.
4. Gebruik `templates/output.md` als rapportstructuur. Vat eerst de semantische
   wijzigingen samen en geef daarna findings op correctness, security,
   schaalbaarheid en tests.
5. Geef per finding severity, evidence met bestand en regel of diff-hunk,
   consequence, confidence en de kleinste geloofwaardige remediation. Vermeld
   ook non-blocking verbeterpunten voor de lange termijn; laat een punt alleen
   weg als er geen controleerbare evidence of concrete verbetering is.
6. Noteer tests als run, not run of unknown met commando en resultaat. Claim
   nooit dat tests slagen zonder uitvoerbare evidence; noem ontbrekende
   repository- of runtime-informatie expliciet.
7. Sluit af met een beperkte verdict voor deze diff. Voer geen edits, commits,
   pushes, dependency-installaties of andere mutaties uit.

## Vijf vragen over schaal en resourcegebruik

1. **Hoe groot is de invoer in productie?** Bepaal wat `n` voorstelt en hoe
   tijd en geheugen meegroeien. Zoek in lussen naar verborgen scans, zoals
   lidmaatschapscontroles op lijsten, sorteren en verwijderen aan het begin.
   Vergelijk testgroottes met onderbouwde productievolumes.
2. **Hoe wordt de data gebruikt?** Beschrijf de bewerkingen en hun frequentie.
   Past de datastructuur bij opzoeken op sleutel, lidmaatschap, FIFO,
   prioriteit of bereikselectie? Overweeg bestaande sets, dictionaries,
   queues, heaps en database-indexen waar die de bewerkingen goedkoper maken.
3. **Wat groeit, en waardoor stopt die groei?** Controleer caches, wachtrijen,
   retries, history en objectreferenties op limieten, opruiming en levensduur.
   Leg vast wanneer geheugen vrijkomt en wat er gebeurt bij een volle buffer.
4. **Hoeveel externe verzoeken veroorzaakt dit?** Tel database-, HTTP-, cache-
   en bestandsoperaties als functie van de invoergrootte. Traceer ook impliciete
   ORM-aanroepen. Beoordeel N+1-patronen, batching en joins op hun concrete
   kosten; een aantal verzoeken dat met `n` groeit is op zichzelf geen finding.
5. **Wie bepaalt de invoer?** Traceer externe invoer naar kostbare bewerkingen.
   Beoordeel de worst case voor bijvoorbeeld regex-backtracking, recursiediepte,
   sorteren en hashing, en controleer de grenzen die die kosten beperken.

Beperk deze analyse tot de diff en relevante aanroepers. Noteer per vraag een
onderbouwd antwoord, `unknown` bij ontbrekende informatie of `not applicable`
met een reden. Label aannames over productievolumes en latentie expliciet.
Rapporteer risico's met hetzelfde evidence-contract als andere findings;
gebruik kleine tests als bewijs voor het gedrag op die testgrootte.

## Output contract

- Begin met scope, current branch, base branch en verdict.
- Beschrijf de belangrijkste gedragswijzigingen vóór de findings.
- Orden findings van high naar low en laat lege categorieën niet als bewezen
  veilig doorgaan.
- Neem ook non-blocking findings op als codeverbetering voor de lange termijn;
   vermeld daarbij altijd bestand en regel of diff-hunk.
- Vermeld gewijzigde files, teststatus, beperkingen en open vragen.
