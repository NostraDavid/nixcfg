# Persoonlijke AI-governancebasis

| Veld | Waarde |
| --- | --- |
| Eigenaar | David |
| Reikwijdte | Uitsluitend persoonlijk, niet-professioneel AI-gebruik |
| Status | Vrijwillige preventieve basis; geen claim van naleving |
| Laatst herzien | 2026-07-13 |
| Herziening vereist | `bij-wijziging` |

## Beoordeling van de reikwijdte

Artikel 2, lid 10, van de EU AI Act sluit de verplichtingen voor
gebruiksverantwoordelijken uit wanneer een natuurlijke persoon AI gebruikt in
het kader van een louter persoonlijke, niet-professionele activiteit. Deze
beoordeling veronderstelt daarom dat er geen sprake is van professioneel werk,
klantwerk, inkomstengenererend gebruik, activiteiten namens een ander of het
aanbieden van een AI-systeem onder de naam van de eigenaar.

De huidige beoogde toepassingen zijn programmeerondersteuning, onderzoek,
documentatie en persoonlijk systeembeheer. Er is geen gebruik met een hoog
risico, openbaar AI-dienstaanbod of aanbiedersrol beoogd. Een wijziging van de
reikwijdte maakt deze beoordeling ongeldig en vereist een herziening voordat er
opnieuw op wordt vertrouwd.

Verplichtingen voor AI-geletterdheid gelden sinds 2 februari 2025 voor
professionele aanbieders en gebruiksverantwoordelijken. De
transparantieverplichtingen uit artikel 50 gelden vanaf 2 augustus 2026. Het
persoonlijke publicatiebeleid in deze repository is vrijwillig en bewust ruimer
dan artikel 50.

## Inventaris van AI-systemen

`Onbekend` betekent dat de aanbieder, het model of de bestemming tijdens de
uitvoering wordt gekozen en niet uit de bijgehouden configuratie kan worden
vastgesteld. Het betekent niet dat de verwerking lokaal plaatsvindt.

| Systeem | Status en doel | Aanbieder/model | Gegevensstroom | Rol en beoogd risico |
| --- | --- | --- | --- | --- |
| Codex en Codex Desktop | Geïnstalleerde en geconfigureerde programmeeragents | OpenAI; `gpt-5.6-sol` | Prompts, code en hulpmiddelresultaten naar een externe dienst | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| Claude | Globale clientconfiguratie aanwezig; programmeer- en algemene hulp | Anthropic; model onbekend | Mogelijke externe verwerking; uitvoeringsdetails onbekend | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| GitHub Copilot CLI | Geïnstalleerde programmeeragent | GitHub; model onbekend | Prompts, code en hulpmiddelresultaten naar een externe dienst | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| Pi | Ingeschakelde programmeeragent | TensorX; `deepseek/deepseek-v4-flash` | Prompts, code en hulpmiddelresultaten naar een extern eindpunt | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| Gemini CLI | Geïnstalleerde algemene en programmeeragent met persoonlijke OAuth | Google; model onbekend | Prompts, code en hulpmiddelresultaten naar een externe dienst | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| OpenCode | Geïnstalleerde aanbieder-onafhankelijke programmeeragent | Aanbieder en model onbekend | Lokale of externe bestemming wordt tijdens uitvoering gekozen | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| Hermes Agent en Desktop | Geïnstalleerde aanbieder-onafhankelijke autonome agent en desktopclient | Aanbieder en model onbekend | Lokale hulpmiddelen; inferentiebestemming wordt tijdens uitvoering gekozen | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| CodeAlmanac | Geïnstalleerde, door AI onderhouden lokale codebasewiki | Claude Agent SDK; model onbekend | Lokale repositorygegevens kunnen naar de geconfigureerde inferentiedienst gaan | Persoonlijke gebruiker; geen beoogd gebruik met een hoog risico |
| Semble | Geïnstalleerde ondersteuning voor semantisch zoeken in code | Lokale Model2Vec-embeddings | Repositoryinhoud wordt na modeldownload lokaal ingebed en doorzocht | Ondersteunende component; geen ingrijpende beslissingen |
| Stable Diffusion CPP | Geïnstalleerde lokale runtime voor beeldgeneratie | Lokale runtime; model onbekend | Prompts en gegenereerde beelden blijven lokaal tenzij afzonderlijk gepubliceerd | Persoonlijke gebruiker; geen hoog risico beoogd; labels gelden |

Skillkit, Context7, RTK en Snip ondersteunen agentwerkstromen, maar zijn niet
als zelfstandige inferentiesystemen in deze inventaris opgenomen. Classificeer
ze opnieuw als hun gedrag wezenlijk verandert.

## Beheersmaatregelen

| Risico | Preventieve beheersmaatregel | Bewijs |
| --- | --- | --- |
| Mogelijk verboden gebruik of hoog risico | Benoem de mogelijke categorie, leg de aanleiding uit en vereis uitdrukkelijke bevestiging vóór het risicovolle onderdeel | Gedeelde `eu-ai-act.md`-regel en clientkoppelingen |
| Ingrijpende of externe actie | Menselijke controle vóór publicatie, contact met derden, een onomkeerbare actie of een beslissing die een ander raakt | Gedeelde regel en normale goedkeuringsstroom |
| Gevoelige of niet-openbare invoer | Waarschuw vóór cloudoverdracht; geef de voorkeur aan redactie, pseudonimisering, synthetische gegevens of lokale verwerking; vereis zo nodig bevestiging | Gedeelde regel; geen registratie van prompts |
| Openbare, door AI gegenereerde tekst/media | Gebruik een opvallend label `AI-generated`/`AI-gegenereerd` of `AI-assisted`/`AI-ondersteund` en behoud herkomstmarkeringen | Gedeelde regel en publicatiecontrole |
| Softwareontwikkelingsartefacten | Broncode, commits, pull requests en releases zijn uitgezonderd van het vrijwillige publicatielabel | Uitdrukkelijke uitzondering in de regel |
| Verouderde governance | Herzie bij wijzigingen in hulpmiddel, model, aanbieder, bestemming, doel, rol of relevante wetgeving | Inventaris en alleen-aanvulbaar herzieningslogboek |

De beheersmaatregelen staan geen gedrag toe dat door andere wetgeving of
platformbeleid wordt verboden. Prompts, geheimen, persoonsgegevens en
gebruikslogboeken per handeling worden niet als bewijs van naleving bewaard.

## Aanleidingen voor herziening

Herzie dit document en de gedeelde regel wanneer:

- een AI-hulpmiddel, model, aanbieder, gegevensbestemming of wezenlijke
  configuratie wordt toegevoegd, verwijderd of gewijzigd;
- het gebruik professioneel, klantgericht of inkomstengenererend wordt, of
  namens een ander plaatsvindt;
- een AI-systeem onder de naam van de eigenaar wordt aangeboden of voor een
  verboden gebied of gebied met een hoog risico wordt overwogen;
- definitieve richtsnoeren voor artikel 50 worden gepubliceerd; of
- de Digital Omnibus on AI of een ander relevant rechtsinstrument in werking
  treedt.

## Herzieningslogboek

Voeg nieuwe vermeldingen toe; herschrijf eerdere beoordelingen niet.

| Datum | Aanleiding | Uitkomst |
| --- | --- | --- |
| 2026-07-13 | Eerste preventieve implementatie vóór 2 augustus 2026 | Uitzondering voor persoonlijk gebruik vastgelegd; inventaris en beheersmaatregelen ingericht. De definitieve transparantiecode en de adequaatheidsbeoordeling zijn opgenomen. Definitieve Artikel 50-richtsnoeren en een definitieve wijzigingsverordening voor de Digital Omnibus zijn niet gevonden en blijven aanleidingen voor herziening. |

## Officiële bronnen

- [Verordening (EU) 2024/1689](https://eur-lex.europa.eu/eli/reg/2024/1689/oj)
- [Artikel 2: reikwijdte en uitzondering voor persoonlijk
  gebruik](https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-2)
- [Vragen en antwoorden over
  AI-geletterdheid](https://digital-strategy.ec.europa.eu/en/faqs/ai-literacy-questions-answers)
- [Artikel 50:
  transparantieverplichtingen](https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50)
- [Definitieve praktijkcode voor transparantie van door AI gegenereerde
  inhoud](https://digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content)
- [Commissieadvies over de adequaatheid van de
  praktijkcode](https://digital-strategy.ec.europa.eu/en/library/commission-opinion-assessment-code-practice-transparency-ai-generated-content)
- [Ontwerprichtsnoeren voor artikel
  50](https://digital-strategy.ec.europa.eu/en/library/draft-guidelines-implementation-transparency-obligations-certain-ai-systems-under-article-50-ai-act)
- [Voorstel voor de Digital Omnibus on
  AI](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:52025PC0836)
