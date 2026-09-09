# Gedeelde agent-skills

Home Manager koppelt elke geselecteerde skill afzonderlijk naar de vlakke
skillmappen van Codex, Copilot en OpenCode. De geïmporteerde selecties staan in
`pkgs/awesome-copilot-skills/skills.nix`, `pkgs/matt-pocock-skills/skills.nix`
en `pkgs/pstack-skills/skills.nix`, plus `pkgs/polars-skills/skills.nix`. Zet
een skill daar op `true` of `false`; `modules/home/dotfiles.nix` verzorgt alleen
de koppelingen en de overige lokale groepen. Dubbele skillnamen geven een
evaluatiefout: schakel eerst de andere variant uit. Codex gebruikt daarnaast
zijn ingebouwde system-skills uit `~/.codex/skills/.system`. Deze worden hier
niet gekopieerd of naar Copilot en OpenCode gekoppeld. Hermes en Pi zijn niet
aan deze selectie gekoppeld.

## Rechtstreekse imports

Awesome Copilot komt via `awesome-copilot-skills` uit `github/awesome-copilot`.
De bestaande baseline `822a551eaf80f6a8e9de8bb19d02f0d0b60ae842` bevat 372
skills. De actieve selectie staat in `pkgs/awesome-copilot-skills/skills.nix`.
Het eerder verwijderde `acquire-codebase-knowledge` blijft uit. De
upstreambestanden worden zonder lokale aanpassingen geïmporteerd.

Matt Pocock wordt zonder lokale aanpassingen geïmporteerd uit
`mattpocock/skills`, via de niet-flake-input `matt-pocock-skills`, gepind op
`v1.2.3`. De selectie staat in `pkgs/matt-pocock-skills/skills.nix`;
geselecteerde skills worden rechtstreeks uit de Nix-store gekoppeld. Er zijn
geen lokale kopieën of upstreamsnapshots.

PStack komt via `pstack-skills` uit
[`cursor/plugins/pstack`](https://github.com/cursor/plugins/tree/main/pstack).
De actieve selectie staat in `pkgs/pstack-skills/skills.nix`. Kies bij gedeelde
namen zoals `tdd` en `teach` één bron via de selectiebestanden. De
Cursor-pluginconfiguratie, agents en automations worden niet geïnstalleerd.

Polars komt via `polars-skills` uit `polars-inc/skills`, gepind op `v0.3.1`.
`polars` staat aan in `pkgs/polars-skills/skills.nix`. De volledige skillmap
komt rechtstreeks uit upstream, inclusief referenties en de upstreamtrigger. Er
is geen lokale variant of snapshot.

`flake.nix` kiest de revisie en `flake.lock` legt de inhoudshash vast. Voor
updates: wijzig de revisie, voer `nix flake lock` uit en controleer of de
skillpaden nog bestaan. De koppelingen worden actief na het toepassen van Home
Manager via de gebruikelijke systeemrebuild.

## Lokale bronnen

De lokale skills staan rechtstreeks onder `.agents/`, elk in een eigen map.
[`.agents/SOURCE.md`](.agents/SOURCE.md) beschrijft herkomst en updategrenzen.
Alle externe collecties komen via Nix-inputs; het voormalige snapshotarchief en
vergelijkingsscript zijn verwijderd.

`interview-me` is een herimplementatie van het workflowidee uit
[`Austin1serb/agents-md`](https://github.com/Austin1serb/agents-md/blob/main/agent-skills/interview-me.md).
Die repository publiceert geen licentie en is niet letterlijk gekopieerd.

Koppel de bronverzameling niet ook aan `~/.agents/skills`: dat kan dezelfde
skills dubbel beschikbaar maken.

## Geheugen en sessiegeschiedenis

`nixcfg.agentMemory.provider` in `modules/home/development/mantle.nix` kiest het
actieve geheugen. Het staat op `"engrim"`; verander dit in `"engram"` en rebuild
om terug te schakelen. Herstart daarna de coding-clients. Beide CLI's blijven
geïnstalleerd. Hun databases worden niet gemigreerd, gesynchroniseerd of
verwijderd bij een switch.

De MCP-configuraties gebruiken `agent-memory mcp`, dat de gekozen backend start.
Home Manager past bij activatie ook de bestaande Codex- en Claude-configuratie
aan en bewaart de oorspronkelijke bestanden met de suffix
`.before-agent-memory`. Andere instellingen en MCP-servers blijven behouden.
`~/.config/agent-memory/provider` vertelt agents welke instructies gelden.
Engrim bewaart geselecteerde kennis in `~/.engrim/memory.db`; het embeddingmodel
komt via Nix mee en kan offline worden gebruikt.

CTX bewaart doorzoekbare sessiegeschiedenis in `~/.ctx`. De user-service
`ctx-history` initialiseert en onderhoudt de index na de rebuild. Controleer hem
met `systemctl --user status ctx-history` en `ctx status`. De upstream
history-search-skill heet in CTX 1.3.1 `ctx` en is beschikbaar voor Codex,
Claude, Copilot, OpenCode en Pi. CLI en skill worden samen bijgewerkt met
`just pkg-update ctx`. Engrim gebruikt de gewone updater via
`just pkg-update engrim`; beide vallen ook onder `just pkg-update-all`.
