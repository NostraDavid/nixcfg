# Gedeelde agent-skills

De skillbronnen staan per herkomst onder `.agents/skill-sources`. Die bronmap
is bewust niet zelf een discoverylocatie. Home Manager projecteert elke skill
afzonderlijk naar vlakke clientmappen, zodat clients dezelfde skillnamen blijven
vinden zonder kennis van de herkomstmappen.

## Herkomst en updates

| Groep                                                                | Aantal | Updatebaseline                                                                                      |
| -------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------------------------- |
| [`codex-system`](.agents/skill-sources/codex-system/SOURCE.md)       | 5      | Codex CLI `0.144.3`, bronmarker `2575ff8690bf93c7`                                                  |
| [`awesome-copilot`](.agents/skill-sources/awesome-copilot/SOURCE.md) | 17     | Lokale importcommit `777aa3ef648e19c400a4c371a459210c66017e06`; upstreamrevisie was niet vastgelegd |
| [`matt-pocock`](.agents/skill-sources/matt-pocock/SOURCE.md)         | 22     | `mattpocock/skills@9603c1cc8118d08bc1b3bf34cf714f62178dea3b`                                        |
| [`local`](.agents/skill-sources/local/SOURCE.md)                     | 14     | Per skill of workflowfamilie vastgelegd in het bronbestand                                          |

De `SOURCE.md` van iedere groep beschrijft de import, lokale aanpassingen en
updateaanpak. Upstreamlicenties staan naast hun groep als `LICENSE.txt`.

De Codex-systemskills zijn ongewijzigde snapshots. Houd hun productspecifieke
instructies intact bij het synchroniseren. De Awesome Copilot- en Matt
Pocock-skills zijn bewust draagbaar gemaakt en moeten bij een upstream-update
opnieuw tegen de lokale aanpassingen worden beoordeeld.

`interview-me` is een compacte herimplementatie van het workflowidee uit
[`Austin1serb/agents-md`](https://github.com/Austin1serb/agents-md/blob/main/agent-skills/interview-me.md).
De upstreamrepository publiceert geen licentie en is daarom niet letterlijk
gekopieerd.

## Actieve clients

- Codex gebruikt de ingebouwde skills uit `~/.codex/skills/.system`; de 53
  overige skills worden individueel gekoppeld onder `~/.codex/skills`.
- GitHub Copilot krijgt alle 58 skills als individuele koppelingen onder
  `~/.copilot/skills`.
- Hermes en Pi zijn nog niet gekoppeld.

De zichtbare clientstructuur blijft dus vlak:

```text
~/.codex/skills/<skillnaam>
~/.copilot/skills/<skillnaam>
```

Koppel de bronverzameling niet ook aan `~/.agents/skills`: Codex ontdekt die
persoonlijke locatie naast zijn system-skills en kan gelijknamige skills dan
dubbel aanbieden.

Na een wijziging detecteert Codex skills doorgaans automatisch. Gebruik in een
lopende Copilot CLI-sessie `/skills reload` en controleer met `/skills list` of
`/skills info <skillnaam>`.
