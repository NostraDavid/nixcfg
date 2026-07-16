# Gedeelde agent-skills

Deze map bevat gedeelde agent-skills. Codex gebruikt zijn originele
system-skills; Home Manager koppelt deze verzameling voor GitHub Copilot aan
`~/.copilot/skills`.

De snapshot is overgenomen uit Codex CLI `0.144.3`, vanuit
`~/.codex/skills/.system`, met bronmarker `2575ff8690bf93c7`. Scripts, assets,
referenties en licentiebestanden zijn meegenomen; lokale bytecodecaches niet.

## Skills

| Skill             | Doel                                                        | Portabiliteit                                                                            |
| ----------------- | ----------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| `imagegen`        | Rasterafbeeldingen genereren en bewerken                    | Primair Codex; verwacht de ingebouwde `image_gen`-tool of de gebundelde OpenAI-CLI-route |
| `openai-docs`     | Actuele OpenAI- en Codex-documentatie raadplegen            | Primair Codex; verwijst naar OpenAI Docs-MCP-tools en de Codex-handleiding               |
| `plugin-creator`  | Codex-plugins en persoonlijke marketplacevermeldingen maken | Codex-specifiek                                                                          |
| `skill-creator`   | Nieuwe skills maken, structureren en valideren              | Grotendeels agent-onafhankelijk, met enkele Codex-paden en Codex-metadata                |
| `skill-installer` | Skills uit OpenAI-catalogi of GitHub installeren            | Primair Codex; installeert standaard onder `$CODEX_HOME/skills`                          |

Daarnaast bevat de verzameling beoordeelde, draagbaar gemaakte workflows voor:

- SQL- en PostgreSQL-review en -optimalisatie;
- requirementsgedreven databaseontwerp en veilige evolutionaire
  databasemigraties;
- security-review, OWASP ASI en GDPR-engineering;
- refactoranalyse, -planning en complexity reduction;
- evidencegedreven software-debugging en risicogestuurd testontwerp;
- continuous delivery, reliability-engineering en Linux-performanceanalyse;
- softwarearchitectuur- en secure-by-design-workflows;
- TigerStyle-ontwerp en -review voor begrensde high-integrity systems code;
- zelfstandige, opinionated Python-CLI-scripts bouwen en herontwerpen;
- specificaties, implementatieplannen, README's en ADR's;
- Excalidraw- en draw.io-diagrammen;
- codebase-onboarding en interactieve intentverheldering.

De meeste van deze workflows zijn afkomstig uit
[`github/awesome-copilot`](https://github.com/github/awesome-copilot) (MIT; zie
`AWESOME-COPILOT-LICENSE.txt`). Copilot-specifieke invoerplaceholders en de
Joyride-afhankelijkheid zijn vervangen door client-onafhankelijke instructies.
`interview-me` is een compacte herimplementatie van het workflowidee uit
[`Austin1serb/agents-md`](https://github.com/Austin1serb/agents-md/blob/main/agent-skills/interview-me.md);
de upstream repository publiceert geen licentie en is daarom niet letterlijk
gekopieerd.

De ingebouwde Codex-skills zijn ongewijzigde snapshots. Houd hun
productspecifieke instructies intact bij het synchroniseren. De overige skills
zijn bewust draagbaar gemaakt en moeten bij een upstream-update opnieuw tegen de
lokale aanpassingen worden beoordeeld.

## Actieve clients

- Codex gebruikt de ingebouwde skills uit `~/.codex/skills/.system`;
  negenentwintig aanvullende skills worden individueel gekoppeld onder
  `~/.codex/skills`.
- GitHub Copilot gebruikt de gedeelde snapshot via `~/.copilot/skills`.
- Hermes en Pi zijn nog niet gekoppeld.

Koppel deze snapshots niet ook aan `~/.agents/skills`: Codex ontdekt die
persoonlijke locatie naast zijn system-skills en kan gelijknamige skills dan
dubbel aanbieden.

Na een wijziging detecteert Codex skills doorgaans automatisch. Gebruik in een
lopende Copilot CLI-sessie `/skills reload` en controleer met `/skills list` of
`/skills info <skillnaam>`.
