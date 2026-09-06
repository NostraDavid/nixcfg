---
id: ADR-SYS-0002
title: Gebruik SQLite voor orders
status: ACCEPTED
domain: SYS
system: Orders
owner: Orders team
decider: Architecture group
decision_date: 2026-02-01
last_reviewed_date: null
supersedes: [ADR-SYS-0001]
superseded_by: []
related: []
---

# Gebruik SQLite voor orders

`ADR-SYS-0002`

## Context and Problem Statement

De orderservice draait nu uitsluitend op één device zonder netwerk. De eerdere
PostgreSQL-keuze was gebaseerd op transacties voor orders en orderregels en
bestaande operationele ervaring. Die consistentiebehoefte blijft gelden, maar
de gewijzigde deployment maakt lokaal beheer met minder componenten bepalend.
PostgreSQL en SQLite zijn voor deze situatie vergeleken.

## Decision Outcome

**Chosen option:** SQLite

Gebruik SQLite als orderopslag. De ingebedde database past bij uitvoering op
één device, ondersteunt transacties en vermijdt beheer van een afzonderlijk
databaseproces. Deze eenvoud weegt zwaarder dan hergebruik van de bestaande
PostgreSQL-beheerervaring. Dit geaccepteerde besluit vervangt ADR-SYS-0001.

## Participants

Orders team is eigenaar en beheert de orderservice. Architecture group is de
decider. Customer support blijft afhankelijk van consistente ordergegevens,
zoals beschreven in de oorspronkelijke beslissing.

## Consequences

### Positive

De opslag kan samen met de applicatie lokaal worden beheerd, zonder afzonderlijk
databaseproces. Orders en orderregels kunnen samen in een transactie worden
opgeslagen.

### Negative

De overstap vraagt migratie van bestaande gegevens en aanpassing van
PostgreSQL-specifieke applicatiecode waar die aanwezig is. Migratie, herstel en
schrijfgedrag moeten vóór ingebruikname worden gecontroleerd; er zijn geen
metingen of migratieresultaten aangeleverd.

### Neutral

Orders team blijft verantwoordelijk voor back-ups en herstel. Deze beslissing
verandert de inhoudelijke consistentiebehoefte van orders en orderregels niet.

## Decision Drivers

| Driver | Relative weight | Description |
| --- | --- | --- |
| Lokale uitvoering | High | De service draait uitsluitend op één device zonder netwerk. |
| Eenvoudig beheer | High | Beperk afzonderlijk te beheren componenten op het device. |
| Consistentie | High | Orders en orderregels moeten samen worden vastgelegd. |
| Bestaande ervaring | Medium | Het team heeft volgens de eerdere ADR PostgreSQL-beheerervaring. |

## Considered Options

| Option | Summary |
| --- | --- |
| SQLite | Ingebedde transactionele opslag op het device. |
| PostgreSQL | Behoud van de bestaande keuze met een lokaal databaseproces. |

### Pros and Cons of the Options

#### SQLite

Geselecteerd omdat ingebedde opslag aansluit bij de nieuwe deployment en de
transactiebehoefte, met minder afzonderlijk databasebeheer.

##### Pros and Cons

- Good, because een afzonderlijk databaseproces niet nodig is.
- Neutral, because back-up- en hersteleigenaarschap bij Orders team blijft.
- Bad, because de bestaande opslag en eventuele PostgreSQL-specifieke code moeten worden gemigreerd.

#### PostgreSQL

Niet geselecteerd voor de nieuwe situatie. Een lokaal PostgreSQL-proces kan
zonder extern netwerk werken en behoudt bestaande ervaring, maar vraagt een
afzonderlijk te beheren databaseproces op het device.

##### Pros and Cons

- Good, because de bestaande databasekennis en opslagkeuze behouden blijven.
- Neutral, because ook bij deze optie lokale back-ups en herstel nodig blijven.
- Bad, because een afzonderlijk databaseproces extra beheer vraagt in deze deployment.

## More Information

Voorgaand besluit: [ADR-SYS-0001](ADR-SYS-0001-use-postgresql.md). De oorspronkelijke
argumentatie en besluitdatum blijven daarin bewaard.

Bron voor de gewijzigde context, goedkeuringsstatus, eigenaar, decider en
besluitdatum is de aangeleverde opdracht binnen deze synthetische evaluatie.
Er zijn geen benchmarkresultaten of uitvoeringsbewijzen aangeleverd.
Heropen de keuze wanneer meerdere devices, netwerktoegang of veranderde
schrijfbelasting nodig worden. Een laatste reviewdatum is niet aangeleverd.
