# agent-rules

Een enigszins merkwaardige configuratie: ik koppel `AGENTS.md` aan
`~/AGENTS.md`, maar maak het bestand ook beschikbaar voor Codex, Claude, Pi en
Gemini. Zo is er één informatiebron, terwijl elke agent toegang tot de regels
houdt.

Ik koppel ook de volledige map `agent-rules/` aan `~/agent-rules/`, zodat de
regels en bijbehorende bestanden gemakkelijk bereikbaar zijn.

De verwijzingen in `AGENTS.md` beginnen vanuit de thuismap. Zonder `$HOME`
zouden nieuwe gesprekken lokaal zoeken en het genoemde `@file` niet vinden.

Clients die de `@file`-verwijzingen in `AGENTS.md` niet volgen, laden de
preventieve EU-AI-Act-regel ook rechtstreeks:

- Copilot ontvangt de regel als een afzonderlijk instructiebestand.
- OpenCode laadt de regel via de globale instelling `instructions`.
- Hermes ontvangt de regel tijdens het bouwen als aanvulling op het declaratief
  beheerde `SOUL.md`; de bestaande Hermes-persona blijft de eerste alinea.
