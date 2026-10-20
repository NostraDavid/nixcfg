# Lokale DBHub-sandbox

DBHub op Wodan gebruikt een eigen SQLite-database:

```text
~/.local/share/dbhub/local.sqlite
```

Codex, de persoonlijke OpenCode-configuratie en Pi starten DBHub wanneer hun
MCP-client verbindt. De verbinding gebruikt stdio. Er is geen permanente
achtergrondservice of luisterende netwerkpoort nodig. De werkconfiguratie is
niet gewijzigd.

De database begint leeg en blijft bewaard tussen clients en herstarts.
`execute_sql` kan hier tabellen aanmaken en gegevens lezen en schrijven.
`search_objects` toont de beschikbare databaseobjecten. Bestaande applicatie- en
productiedatabases zijn niet aangesloten.

De clients gebruiken expliciet `~/.config/dbhub/local.toml`. Daardoor kiezen ze
geen `dbhub.toml` uit de huidige projectmap. Home Manager genereert deze
configuratie vanuit `features/mcp/_home.nix` en maakt de datamap privé.

## Controleer de aansluiting

Laat Codex de nieuwe MCP-configuratie laden. In de gecontroleerde actieve sessie
waren beide tools direct beschikbaar. Controleer OpenCode met
`opencode mcp list` en Pi met `pi mcp list`. Vraag de agent daarna om via DBHub
`SELECT 42 AS connection_check` uit te voeren.

De regressietest gebruikt tijdelijke databases:

```bash
node checks/test-dbhub.mjs
```

Deze test controleert MCP-initialisatie, beide tools, schrijven en teruglezen
via afzonderlijke DBHub-processen. Hij controleert ook dat het expliciete
configuratiebestand voorrang krijgt op projectconfiguratie en `DSN`.
