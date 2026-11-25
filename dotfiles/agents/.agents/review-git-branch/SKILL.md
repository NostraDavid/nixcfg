---
name: review-git-branch
description: "Review branch or PR changes against the base branch for correctness, security, scalability, tests, and merge readiness. Exclude specialized security, API-schema, performance-only, Twelve-Factor, and architecture-only reviews."
---

# PR Review

Voer de review read-only uit. Baseer alle claims op het vergelijkingsrapport,
de repository-instructies en controleerbaar bewijs uit de broncode of tests.

## Workflow

1. Open en lees [git-review-report.md](templates/git-review-report.md) vanuit
   de map van dit `SKILL.md` voordat je de review begint. Vul de template in
   volgens de HTML-commentaren en geef het ingevulde rapport zonder die
   commentaren.
2. Gebruik een aangeleverd rapport van `branch-compare.sh` voor de gevraagde
   vergelijking. Bepaal anders de repository-root en voer het gebundelde script uit.

   `bash ~/.agents/skills/review-git-branch/scripts/branch-compare.sh --repo <repository-root>`

   Gebruik `--base <git-ref>` wanneer de gebruiker een base noemt. Het script
   geeft één Markdown-rapport met base, merge-base, commits, diff-stat,
   gewijzigde paden, diff-checks en patch. Gebruik het rapport als primaire
   diff-input.
3. Als het script faalt of de diff leeg is, meld dan de reden in plaats van
   een inhoudelijke review. Vraag om een expliciete base-ref
   wanneer nodig.
4. Lees toepasselijke `AGENTS.md`-, `README`-, CI- en testinstructies voordat
   je conclusies trekt. Inspecteer de gewijzigde files en relevante context.
   Beantwoord de vijf vragen hieronder voor de gewijzigde code die data verwerkt.
5. Vergelijk je antwoord vóór verzending met de gelezen template. Controleer
   de sectiekoppen, hun volgorde en de ingevulde velden. Noteer `unknown`
   bij ontbrekend bewijs of `not applicable` met een reden.

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
