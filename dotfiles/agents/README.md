# Gedeelde agent-skills

Deze map bevat een snapshot van de ingebouwde Codex-skills. Codex gebruikt de
originele system-skills; Home Manager koppelt deze snapshot voor GitHub Copilot
aan `~/.copilot/skills`.

De snapshot is overgenomen uit Codex CLI `0.144.3`, vanuit
`~/.codex/skills/.system`, met bronmarker `2575ff8690bf93c7`. Scripts, assets,
referenties en licentiebestanden zijn meegenomen; lokale bytecodecaches niet.

## Skills

| Skill | Doel | Portabiliteit |
| --- | --- | --- |
| `imagegen` | Rasterafbeeldingen genereren en bewerken | Primair Codex; verwacht de ingebouwde `image_gen`-tool of de gebundelde OpenAI-CLI-route |
| `openai-docs` | Actuele OpenAI- en Codex-documentatie raadplegen | Primair Codex; verwijst naar OpenAI Docs-MCP-tools en de Codex-handleiding |
| `plugin-creator` | Codex-plugins en persoonlijke marketplacevermeldingen maken | Codex-specifiek |
| `skill-creator` | Nieuwe skills maken, structureren en valideren | Grotendeels agent-onafhankelijk, met enkele Codex-paden en Codex-metadata |
| `skill-installer` | Skills uit OpenAI-catalogi of GitHub installeren | Primair Codex; installeert standaard onder `$CODEX_HOME/skills` |

De skills zijn ongewijzigde snapshots. Houd productspecifieke instructies intact
bij het synchroniseren; voeg generieke varianten als afzonderlijke skills toe in
plaats van lokale vendorwijzigingen bij een volgende Codex-update te overschrijven.

## Actieve clients

- Codex gebruikt de ingebouwde skills uit `~/.codex/skills/.system`.
- GitHub Copilot gebruikt de gedeelde snapshot via `~/.copilot/skills`.
- Hermes en Pi zijn nog niet gekoppeld.

Koppel deze snapshots niet ook aan `~/.agents/skills`: Codex ontdekt die
persoonlijke locatie naast zijn system-skills en kan gelijknamige skills dan
dubbel aanbieden.

Na een wijziging detecteert Codex skills doorgaans automatisch. Gebruik in een
lopende Copilot CLI-sessie `/skills reload` en controleer met `/skills list` of
`/skills info <skillnaam>`.
