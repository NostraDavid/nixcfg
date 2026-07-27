# Originele skill-snapshots

Deze map bewaart onveranderde bronversies naast de actieve, lokaal aangepaste
varianten in [`../skill-sources`](../skill-sources/README.md). Home Manager
projecteert uitsluitend `skill-sources`; niets onder `skill-originals` wordt
door Codex of Copilot als actieve skill gekoppeld.

## Snapshots

| Groep | Snapshot | Status | Herkomst |
| --- | --- | --- | --- |
| `awesome-copilot` | `822a551eaf80f6a8e9de8bb19d02f0d0b60ae842` | Gereconstrueerde baseline | Laatste commit op `github/awesome-copilot` vóór de lokale import van 16 juli 2026 |
| `matt-pocock` | `v1.1.0` | Releasebaseline | De door upstream gepubliceerde release van 8 juli 2026 |
| `codex-system` | `codex-cli-0.144.3_2575ff8690bf93c7` | Exacte baseline | De vijf gebundelde system-skills uit lokale importcommit `8325a250` |
| `polars-inc` | `v0.2.0` | Releasebaseline | De door upstream gepubliceerde release van 23 juni 2026 |

De Awesome Copilot-SHA is de beste reproduceerbare reconstructie, maar kan niet
als de bewezen oorspronkelijke import-SHA worden beschouwd: die SHA is destijds
niet opgeslagen. De snapshot is wel ongewijzigd uit de upstreamrepository
overgenomen. Awesome Copilot heeft geen repositorybrede tags of releases.
Slechts één van de zeventien geselecteerde skills declareert zelf een semantische
versie. Daarom bewaart
[`VERSIONS.md`](awesome-copilot/822a551eaf80f6a8e9de8bb19d02f0d0b60ae842/VERSIONS.md)
per skill zowel een eventueel gedeclareerde versie als de laatste upstreamcommit
en wijzigingsdatum.

De groep `local` heeft geen spiegel in dit archief. Die skills zijn lokale
originelen of bewuste herimplementaties; hun individuele herkomst staat in
[`../skill-sources/local/SOURCE.md`](../skill-sources/local/SOURCE.md).

## Vergelijken

Een samenvatting voor alle skills:

```console
./dotfiles/agents/.agents/skill-originals/compare.sh
```

Een volledige diff voor één skill:

```console
./dotfiles/agents/.agents/skill-originals/compare.sh matt-pocock code-review
```

De samenvatting telt gewijzigde bestanden en bestanden die slechts aan één kant
bestaan. Opmaakwijzigingen tellen daarbij ook als verschil; beoordeel een
inhoudelijke afwijking daarom altijd met de volledige diff.
Een volledige diff eindigt volgens de conventie van `diff` met status 1 wanneer
er verschillen zijn.

## Bijwerken

Snapshots zijn onveranderlijk. Voeg een nieuwe upstreamrevisie als nieuwe map
naast de bestaande revisie toe en werk deze README bij. Bewerk bestanden onder
`skill-originals` niet om ze met de lokale varianten gelijk te trekken. De
snapshots bewaren ook upstream trailing whitespace; `.gitattributes` sluit
alleen deze archiefpaden daarom uit van Git's trailing-whitespacecontrole.
