# Gedeelde agent-instructies

Deze map is de canonieke bron voor gedeelde instructies. Home Manager koppelt
`AGENTS.md` aan `~/AGENTS.md` en maakt hetzelfde bestand beschikbaar voor
Codex, Claude, Pi en Gemini. Zo is er één informatiebron, terwijl elke agent
toegang tot de instructies houdt.

Ik koppel ook de volledige instructiemap aan `~/.agents/instructions/`, zodat de
instructies en bijbehorende bestanden gemakkelijk bereikbaar zijn. De verborgen
map `~/.agents/` groepeert daarmee gedeelde instructies en runtimegegevens zoals
skills en plugins. Alleen productspecifieke locaties en `.agents/skills` worden
automatisch ontdekt; `.agents/instructions` is een intern gedeeld bronpad.

De verwijzingen in `AGENTS.md` beginnen vanuit de thuismap. Zonder `$HOME`
zouden nieuwe gesprekken lokaal zoeken en het genoemde `@file` niet vinden.

Clients die de `@file`-verwijzingen in `AGENTS.md` niet volgen, laden de
preventieve EU-AI-Act-regel ook rechtstreeks:

- Copilot ontvangt de regel als een afzonderlijk instructiebestand.
- OpenCode laadt de regel via de globale instelling `instructions`.
- Hermes ontvangt de regel tijdens het bouwen als aanvulling op het declaratief
  beheerde `SOUL.md`; de bestaande Hermes-persona blijft de eerste alinea.
