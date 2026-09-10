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

## Korte symlinknamen

`skills.json` bevat onder `aliases` de vaste korte mapnamen, bijvoorbeeld
`blender-materials` → `bmat`, `database-refactor` → `dbref` en
`postgresql-optimization` → `pgopt`. Codex, Copilot en OpenCode gebruiken
dezelfde aliassen; de gedeelde workflowlinks onder `~/.agents/skills` ook. De
bronmappen blijven behouden; het `name`-veld in `SKILL.md` gebruikt dezelfde
korte alias. Nieuwe skills zonder alias gebruiken hun bronnaam totdat je een
korte naam toevoegt. Dubbele linknamen geven een evaluatiefout.

Home Manager vervangt de oude links bij de volgende activatie. Verwijzingen in
de gedeelde instructies gebruiken de korte paden. De aparte ingang
`~/.agents/audio-notify/` blijft beschikbaar voor clients zonder skillselectie.
Geïmporteerde skills krijgen hun korte naam in een aparte Nix-build. Die werkt
ook verwijzingen naar hernoemde skills bij, met behoud van bronpaden. De gepinde
upstreambronnen blijven onaangetast. Lokale `SKILL.md`-bestanden bevatten de
korte namen rechtstreeks.

Ingebouwde skills, pluginmappen en submappen binnen upstreamskills worden door
hun eigen distributie beheerd en vallen buiten deze symlinknamenlijst.

## Beschrijvingsbudget

`descriptions.json` bewaart de beschrijvingen, de grens van 50 tokens en de
`gpt-5`-tokenizer (`o200k_base`). Elke beschrijving blijft strikt onder die
grens. `just check-agent-instructions` telt echte tokens met gepinde
tokenizerdata, controleert de volledige lijst en vergelijkt de beheerde skills
met de lijst.

`checks/skill-trigger-cases.json` bewaart oorspronkelijke beschrijvingen,
belangrijke triggerbepalingen en positieve en negatieve voorbeeldvragen voor
herstelde grenzen. De checks bewaken die bepalingen. De voorbeelden zijn
statisch beoordeeld; modelactivatie is daarmee niet gemeten.

Pas bij wijzigingen de centrale lijst en de betrokken lokale `SKILL.md` aan. De
Nix-build past de teksten toe op geïmporteerde skills. Home Manager past bekende
beschrijvingen bij activatie ook toe op ingebouwde Codex-skills en
pluginbestanden. Na een pluginupdate kan tot de volgende activatie tijdelijk de
upstreambeschrijving terugkomen. Nieuwe skills moeten aan de lijst worden
toegevoegd; beschrijvingen worden inhoudelijk ingekort, niet afgekapt.

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

`audio-notify` speelt een geluid bij vragen aan de gebruiker en bij het afronden
van een taak. De gedeelde `AGENTS.md` verwijst naar de skill via
`~/.agents/audio-notify/`, ook voor clients zonder de gedeelde skillselectie. Na
een Home Manager-rebuild kun je beide geluiden proberen:

```bash
"$HOME/.agents/audio-notify/scripts/notify.sh" question "Welke stem wil je gebruiken?"
"$HOME/.agents/audio-notify/scripts/notify.sh" done "Repositorynaam toegevoegd aan de meldingen."
```

Voer `notify.sh` uit vanuit de repository waar de taak over gaat. Geef als
tweede argument een korte omschrijving mee van wat klaar is of welke input je
nodig hebt. Houd die op maximaal twaalf woorden. Je hoort bijvoorbeeld: "biep
boep. nixcfg. Repositorynaam toegevoegd aan de meldingen.". De naam komt uit de
gedeelde Git-map; `trunk`, submappen en andere worktrees krijgen zo dezelfde
projectnaam. Buiten Git vervalt de naam. De toevoeging hoort bij de gesproken
agentmeldingen. Home Manager koppelt `dotfiles/scripts/say.sh` aan
`~/.local/bin/say`. `say.sh` gebruikt `espeak-ng` met de Nederlandse
steminstellingen en spreekt de opgegeven tekst uit.

`say`, `espeak-ng` en `timeout` moeten op `PATH` staan. Een shellalias werkt
niet vanuit `notify.sh` of `timeout`. Zet `AGENT_NOTIFY_MUTE=1` om de meldingen
te dempen. De meldingen hangen af van het volgen van de instructies door het
model en toegestane uitvoering van het afspeelcommando; er wordt geen clienthook
geïnstalleerd.

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
