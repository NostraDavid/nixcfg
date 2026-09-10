# Gedeelde agent-instructies

Deze map is de canonieke bron voor gedeelde instructies. Home Manager koppelt
`AGENTS.md` aan `~/AGENTS.md` en maakt hetzelfde bestand beschikbaar voor Codex,
Claude, Pi, OpenCode, Copilot en Hermes. Zo is er één informatiebron, terwijl
elke agent toegang tot de instructies houdt.

Ik koppel ook de volledige instructiemap aan `~/.agents/instructions/`, zodat de
instructies en bijbehorende bestanden gemakkelijk bereikbaar zijn. De verborgen
map `~/.agents/` groepeert daarmee gedeelde instructies en runtimegegevens zoals
skills en plugins. Alleen productspecifieke locaties en `.agents/skills` worden
automatisch ontdekt; `.agents/instructions` is een intern gedeeld bronpad.

De verwijzingen in `AGENTS.md` beginnen vanuit de thuismap. Zonder `$HOME`
zouden nieuwe gesprekken lokaal zoeken en het genoemde `@file` niet vinden.

De lokale skillcatalogus staat in `dotfiles/agents/skills.json`. De groep
`workflow` bevat Context7, Headroom, Git-worktrees, code-navigatie, Beads,
geheugenprocedures en CLI-uitvoer. Home Manager koppelt deze aan
`~/.agents/skills/` en aan de skillmappen van Codex, Copilot en OpenCode. De
overige lokale skills krijgen de bestaande clientspecifieke koppelingen.

De basisinstructies bevatten de toolvoorkeuren, geheugen- en proxyregels,
commitstijl en worktreebasis. Voorwaardelijke verwijzingen laden de procedures
bij een passende taak. Code-navigatie gebruikt de MCP-toolbeschrijvingen voor
Qartez en Serena; de Probe-CLI en beide geheugenbackends hebben afzonderlijke
referentiebestanden binnen hun skill.

Voer `just check-agent-instructions` uit na wijzigingen. Deze Nix-check toetst
alle geregistreerde lokale skills op unieke namen en geldige frontmatter,
controleert bestandsverwijzingen in de gedeelde instructies en workflowskills,
en bouwt en controleert hun Home Manager-symlinks. Hij valideert de configuratie
zonder een geactiveerde gebruikersomgeving nodig te hebben. De check draait ook
via `just lint`, de relevante pre-commit-hook en `nix flake check`.
Geïmporteerde skillnamen vallen onder de bestaande Nix-controle op duplicaten;
inhoudelijke validatie van externe bibliotheken valt buiten deze check.

Clients die de `@file`-verwijzingen in `AGENTS.md` niet volgen, laden de
preventieve EU-AI-Act-regel ook rechtstreeks:

- Copilot ontvangt de regel als een afzonderlijk instructiebestand.
- Hermes ontvangt de regel tijdens het bouwen als aanvulling op het declaratief
  beheerde `SOUL.md`; de bestaande Hermes-persona blijft de eerste alinea.
