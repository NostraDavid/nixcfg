---
id: ADR-SYS-0001
title: "Cachekeuze voor Catalog"
status: DRAFT
domain: SYS
system: Catalog
owner: "TODO: Eigenaar bepalen"
decider: "TODO: Goedkeurder bepalen"
decision_date: null
last_reviewed_date: null
supersedes: []
superseded_by: []
related: []
---

# Cachekeuze voor Catalog

`ADR-SYS-0001`

## Context and Problem Statement

Voor Catalog bestaat het vermoeden dat latency een probleem vormt. Er zijn geen
metingen aangeleverd die omvang, oorzaak of gebruikersimpact aantonen. Dit
concept vergelijkt geen cache met een gedeelde cache. De huidige inrichting is
onbekend; geen cache is daarom een kandidaat en niet een bevestigde beschrijving
van de bestaande situatie.

Verkeerspatroon, verhouding tussen lezen en schrijven, toegestane veroudering
van gegevens en operationele randvoorwaarden zijn nog onbekend. Er is
onvoldoende bewijs om een cachekeuze te rechtvaardigen.

## Decision Outcome

**Chosen option:** Undecided

Er is nog geen besluit genomen. Geen van beide opties is geselecteerd of
verworpen. De voorlopige vervolgstap is latency en de achterliggende bewerkingen
meten, daarna toetsen of herhaald lezen voldoende voorkomt en tijdelijke
veroudering acceptabel is. Een gedeelde cache is pas verdedigbaar als deze
aantoonbaar bijdraagt aan een afgesproken latencydoel en de extra beheerlast en
consistentierisico's aanvaardbaar zijn. Geen cache blijft een volwaardige optie
wanneer Catalog aan het doel voldoet of de bottleneck elders ligt.

TODO: Eigenaar en goedkeurder aanwijzen, latencydoel vaststellen, meetresultaten
verzamelen en de afweging afronden. De besluitdatum blijft onbekend tot een
besluit is genomen.

## Participants

TODO: Betrokken personen en teams bevestigen. Te betrekken rollen zijn de
verantwoordelijken voor Catalog, operationeel beheer en productvereisten; dit
zijn voorgestelde rollen, geen bevestigde deelnemers.

## Consequences

De onderstaande gevolgen zijn voorwaardelijk: er is nog geen keuze of
implementatie vastgesteld.

### Positive

Metingen kunnen een keuze onderbouwen en onnodige infrastructuur voorkomen. Een
gedeelde cache kan bij voldoende cachehits herhaalde bronbevragingen
verminderen; geen cache voorkomt de extra cachecomponent.

### Negative

De besluitvorming vergt eerst meetwerk. Een keuze voor geen cache kan een
eventueel bewezen latencyprobleem laten bestaan. Een gedeelde cache voegt beheer
en risico op verouderde gegevens toe; vooraf moeten omgang met invalidatie en
uitval worden uitgewerkt.

### Neutral

Er zijn op dit moment geen bevestigde neutrale gevolgen bekend. Beide opties
moeten worden beoordeeld tegen dezelfde nog vast te stellen eisen voor Catalog.

## Decision Drivers

De gewichten zijn voorstellen voor bespreking en nog niet met betrokkenen
bevestigd.

| Driver                     | Relative weight | Description                                                                                        |
| -------------------------- | --------------- | -------------------------------------------------------------------------------------------------- |
| Latency                    | High            | Vermoed probleem; TODO: gebruikersrelevant doel en representatieve nulmeting bepalen.              |
| Correctheid en actualiteit | High            | TODO: toegestane veroudering vaststellen voordat een cachevariant kan worden beoordeeld.           |
| Beheerlast                 | Medium          | Extra infrastructuur vraagt operationele verantwoordelijkheid; beschikbare capaciteit is onbekend. |
| Kosten                     | Medium          | TODO: bronbelasting, infrastructuurkosten en beheerinspanning voor beide opties vergelijken.       |

## Considered Options

| Option         | Summary                                                                               |
| -------------- | ------------------------------------------------------------------------------------- |
| Geen cache     | Catalog gebruikt geen aanvullende cachelaag; de bron wordt rechtstreeks geraadpleegd. |
| Gedeelde cache | Catalog gebruikt een gedeelde cache voor daarvoor geschikte leesresultaten.           |

### Pros and Cons of the Options

#### Geen cache

Niet geselecteerd of verworpen: deze optie is passend als de bron aan het
latencydoel voldoet of caching het gemeten knelpunt niet oplost. De bestaande
inrichting moet nog worden bevestigd.

##### Pros and Cons

- Good, omdat geen extra cache-infrastructuur of cache-invalidatie nodig is.
- Neutral, omdat de bron de gegevens blijft leveren; een afzonderlijk neutraal
  effect op het gebruikersgedrag is nog niet vastgesteld.
- Bad, omdat herhaalde bevragingen de bron blijven belasten; de feitelijke
  invloed op latency is niet gemeten.

#### Gedeelde cache

Niet geselecteerd of verworpen: deze optie vereist bewijs dat herbruikbare
leesresultaten beschikbaar zijn en cachehits voldoende effect hebben. Het is nog
onbekend welke gegevens geschikt zijn en welke actualiteit nodig is.

##### Pros and Cons

- Good, omdat cachehits bronbevragingen kunnen besparen en daarmee latency
  kunnen verminderen; de verwachte hitratio is onbekend.
- Neutral, omdat een cache op zichzelf de functionele betekenis van de
  catalogusgegevens niet hoeft te veranderen; de concrete gebruikersimpact moet
  nog worden vastgesteld.
- Bad, omdat cachemisses, invalidatie en cache-uitval moeten worden afgehandeld
  en verouderde gegevens een risico kunnen vormen.

## More Information

Bron: de aangeleverde vraag noemt Catalog, domein SYS, twee opties en een
ongemeten vermoeden over latency. Er zijn geen meetrapporten, bestaande ADRs of
bevestigde deelnemers aangeleverd.

TODO: Leg representatieve lees- en schrijflast, end-to-end latency en tijd in
achterliggende bewerkingen vast. Spreek vooraf het latencydoel en
acceptatiecriteria af; vergelijk beide opties onder dezelfde omstandigheden als
caching daarna nog kansrijk is. Leg voor de gedeelde cache ook
gegevensactualiteit, missgedrag en uitvalgedrag vast.

Herbeoordeel dit concept zodra meetresultaten en eisen beschikbaar zijn. Vul
daarna eigenaar, goedkeurder, gekozen optie en besluitdatum in op basis van
bevestigde informatie. Goedkeuring is niet gegeven.

Dit bestand is een geïsoleerd evaluatieconcept. Nummer 0001 is alleen binnen
deze nieuwe evaluatiecollectie toegewezen; historische nummeruniciteit in een
productiecollectie is niet onderzocht.
