# MCP-servers voor wodan

Onderzocht op 20 oktober 2026. Dit advies combineert de lokale inventarisatie
van wodan met primaire documentatie van de serverprojecten. Prioriteiten zijn
een beoordeling voor deze machine, geen ranglijst van alle MCP-servers.

Het meeste nut zit al op deze machine. Gebruik MCP-NixOS voor Nix-vragen en de
bestaande browsertools voor interactieve inspectie. DBHub is de beste gerichte
vervolgstap wanneer je een concrete database wilt aansluiten. GitHub MCP heeft
daarna waarde bij veel onderzoek naar issues, pull requests en Actions. Voor
incidentele opdrachten zijn de aanwezige CLI's voldoende.

## Wat er al is

Wodan draait Linux op x86_64. De lokale PATH bevat onder meer `nix`, `gh`,
`kubectl`, `podman`, `psql`, `dbhub`, `qartez`, `ctx7`, `mcporter`,
`playwright-mcp`, `mcp-nixos` en `chrome-devtools-mcp`. Aanwezigheid zegt nog
niets over een werkende verbinding of toegangsrechten.

[features/mcp/_home.nix](../features/mcp/_home.nix) configureert MCP-NixOS,
Playwright en Chrome DevTools voor Codex en OpenCode. Playwright en Chrome
DevTools gebruiken headless, geïsoleerde browsers. Chrome DevTools heeft hier
`--no-usage-statistics` en `--no-performance-crux`. Dezelfde module installeert
DBHub. [inventory/_wodan-home.nix](../inventory/_wodan-home.nix) installeert
Playwright CLI met bijbehorende skills.
[pkgs/dbhub/default.nix](../pkgs/dbhub/default.nix) bevat het lokale
DBHub-pakket.

De gecontroleerde lokale configuraties bevatten deze servernamen:

| Configuratie                       | Servernamen                                                                                        |
| ---------------------------------- | -------------------------------------------------------------------------------------------------- |
| `~/.codex/config.toml`             | agent-memory, chrome-devtools, headroom, nixos, node_repl, openaiDeveloperDocs, playwright, qartez |
| `~/.config/opencode/opencode.json` | chrome-devtools, engram, headroom, nixos, playwright, qartez                                       |
| `~/.config/mcp/mcp.json`           | agent-memory, headroom, qartez                                                                     |

Deze lijsten tonen configuratieverschillen. Ze bewijzen geen fout, aliasgedrag
of geslaagde verbinding. Ook Pi heeft configuratie in de repository via
[features/mcp/_pi.nix](../features/mcp/_pi.nix), maar het verwachte lokale
bestand `~/.pi/agent/mcp.json` ontbrak bij deze inventarisatie. Daaruit volgt
geen conclusie over de actieve Pi-runtime.

## Welke servers hier waarde toevoegen

| Prioriteit                | Server en herkomst                                   | Status op wodan                                             | Meerwaarde en advies                                                                                                             |
| ------------------------- | ---------------------------------------------------- | ----------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| Hoog                      | MCP-NixOS, communityproject `utensils`               | Geïnstalleerd en geconfigureerd                             | Pakketnamen, NixOS-opties en Home Manager-opties gericht opzoeken. Bestaande aansluiting benutten.                               |
| Bij databasewerk          | DBHub, van Bytebase                                  | Aangesloten op lokale SQLite-sandbox                        | Schema's en SQL via een vaste MCP-interface. Alleen een concrete ontwikkel- of leesdatabase aansluiten.                          |
| Bij veel GitHub-werk      | GitHub MCP, officieel van GitHub                     | Niet geconstateerd in de gecontroleerde clientconfiguraties | Issues, reviews en CI-gegevens als agenttools. Eerst alleen lezen en beperkte toolsets.                                          |
| Bij interactieve webtaken | Playwright MCP, van Microsoft                        | Geïnstalleerd en geconfigureerd                             | Een browsercontext vasthouden tijdens verkennende interactie. Voor herhaalbare codingtaken is de geïnstalleerde CLI vaak genoeg. |
| Bij webdiagnose           | Chrome DevTools MCP, van het Chrome DevTools-project | Geïnstalleerd en geconfigureerd                             | Performance traces, netwerkverzoeken en consolemeldingen onderzoeken. Op afroep gebruiken.                                       |
| Laag                      | Context7 MCP, van Upstash                            | `ctx7` CLI aanwezig, geen MCP-aansluiting geconstateerd     | Versiegerichte bibliotheekdocumentatie als native tools. Alleen toevoegen als de CLI-route tekortschiet.                         |
| Voorwaardelijk            | Kubernetes MCP, project `containers`                 | `kubectl` aanwezig, server niet geconstateerd               | Clusteronderzoek via de Kubernetes API. Pas nuttig bij regelmatig werk aan een werkelijk gebruikt cluster.                       |

De volgende paragrafen onderbouwen de mogelijkheden en de keuze per server.

### MCP-NixOS sluit direct aan op deze repository

MCP-NixOS zoekt pakketten, configuratieopties en Nix-documentatie. De huidige
upstream documenteert ook het lezen van lokale flake-inputs uit de Nix store en
het opzoeken van pakketversies. Het is een communityserver, geen officieel
NixOS-project. [Bron: MCP-NixOS README](https://github.com/utensils/mcp-nixos).

De meerwaarde is vooral zoeken zonder vooraf de juiste attribuutnaam te kennen.
Voor de vraag wat jouw gepinde flake daadwerkelijk ondersteunt, blijven lokale
bronnen en `nix eval` nodig. De upstreamcatalogus kan afwijken van de revisies
in `flake.lock`. Controleer bovendien welke tools de lokaal gepinde serverversie
aanbiedt voordat je de huidige upstream-interface gebruikt.

### DBHub verdient een gerichte proef bij databasewerk

DBHub biedt standaard `search_objects` en `execute_sql`. Het ondersteunt onder
meer PostgreSQL en SQLite en kan meerdere verbindingen uit TOML laden.
[Bron: Bytebase DBHub README](https://github.com/bytebase/dbhub).

Daarmee kan een agent schema's verkennen en vervolgens queries uitvoeren via
dezelfde verbinding. Bij een enkele bekende PostgreSQL-query voegt het weinig
toe aan `psql`. Na deze inventarisatie is DBHub op verzoek aangesloten op een
eigen lokale SQLite-sandbox voor Codex, OpenCode en Pi. Zie
[Lokale DBHub-sandbox](dbhub-local.md) voor het bestand en de verbindingstests.

Voor een toekomstige aansluiting past een beperkte databasegebruiker met
`readonly = true`, een resultaatlimiet en een querytimeout. DBHub waarschuwt
zelf dat alleen-lezenmodus geen voldoende grens vormt voor een databasebeheerder
met bijzondere rechten.
[Bron: execute_sql en alleen-lezenmodus](https://dbhub.ai/tools/execute-sql). De
nu beschikbare upstreambescherming hoeft niet gelijk te zijn aan die van het
lokaal gepinde pakket. Controleer die versie vóór aansluiting.

### GitHub MCP is optioneel naast gh

De officiële GitHub-server geeft toegang tot repositorygegevens, issues, pull
requests en Actions. GitHub biedt een gehoste en een lokale uitvoering.
[Bron: GitHub MCP README](https://github.com/github/github-mcp-server). De
server ondersteunt alleen-lezenmodus en selectie van toolsets of individuele
tools.
[Bron: GitHub-serverconfiguratie](https://github.com/github/github-mcp-server/blob/main/docs/server-configuration.md).

De winst boven `gh` zit in terugkerende gesprekken waarin een agent meerdere
GitHub-objecten moet onderzoeken. Voor een losse PR of log is `gh` al geschikt.
Een proef kan beperkt blijven tot de benodigde leesfuncties voor repositories,
issues en pull requests. Actions pas toevoegen als dat werk werkelijk voorkomt.
Deze aanbeveling geldt voor GitHub. Het lokale Forgejo-lab heeft een andere API.

### Playwright en Chrome DevTools hebben verschillende taken

Playwright MCP gebruikt gestructureerde toegankelijkheidssnapshots voor
browserinteractie. Microsoft noemt CLI met skills zelf als alternatief voor
coding agents, vanwege de contextkosten. MCP blijft volgens upstream nuttig voor
langdurige interacties met aanhoudende browsercontext en rijke inspectie.
[Bron: Playwright MCP tegenover CLI](https://github.com/microsoft/playwright-mcp#playwright-mcp-vs-playwright-cli).

Daarom past de bestaande combinatie op wodan. Gebruik de CLI voor herhaalbare
handelingen en MCP wanneer het onderzoek een doorlopende sessie nodig heeft. Een
extra algemene browser-MCP biedt hier geen aangetoonde meerwaarde.

Chrome DevTools MCP leest netwerkverzoeken en consolemeldingen en kan
performance traces opnemen. Upstream ondersteunt officieel Google Chrome en
Chrome for Testing. Andere Chromium-browsers kunnen werken, maar krijgen die
garantie niet. De wodan-config gebruikt Chromium. De aanwezige opt-outflags
schakelen de gedocumenteerde gebruiksstatistieken en CrUX-verzoeken uit.
[Bron: Chrome DevTools MCP README](https://github.com/ChromeDevTools/chrome-devtools-mcp).
Voor een echt browserprobleem blijft een lokale proef dus nodig.

### Context7 heeft hier al een CLI-route

Context7 haalt versiegerichte bibliotheekdocumentatie en voorbeelden op. De
MCP-code is openbaar, maar de achterliggende API en indexeercomponenten staan
niet in die repository.
[Bron: Context7 MCP README](https://github.com/upstash/context7/blob/master/packages/mcp/README.md).

Omdat `ctx7` al beschikbaar is, is een tweede aansluiting vooral een keuze voor
de clientinterface. Er is geen aangetoonde functionele noodzaak. De bestaande
`openaiDeveloperDocs`-aansluiting dekt bovendien al een specifiek
documentatiedomein. Zoekopdrachten aan een externe documentatieservice horen
geen tokens, verbindingsgegevens of vertrouwelijke code te bevatten.

### Kubernetes MCP alleen bij structureel clusterwerk

`containers/kubernetes-mcp-server` spreekt de Kubernetes API direct aan en kan
meerdere clusters uit kubeconfig gebruiken. Het is een afzonderlijk project
onder `containers`, geen hier aangetoonde officiële Kubernetes-server.
[Bron: Kubernetes MCP README](https://github.com/containers/kubernetes-mcp-server).
Het heeft een alleen-lezenoptie. De standaardwaarde daarvan is `false`.
[Bron: configuratiereferentie](https://github.com/containers/kubernetes-mcp-server/blob/main/docs/configuration.md).

Dit wordt interessant bij regelmatig onderzoek naar workloads, events en logs.
De aanwezigheid van `kubectl` bewijst geen actieve clusterbehoefte. Zonder die
behoefte levert de CLI minder beheer op. Bij een latere proef passen een
expliciete kubeconfig, beperkte RBAC-rechten en alleen-lezenmodus.

Het gedocumenteerde lokale lab gebruikt Proxmox, Forgejo en OpenTofu en heeft al
opdrachten voor start, status en stop.
[Bron: lokale labhandleiding](proxmox-lab.md). Een Kubernetes-server helpt daar
niet rechtstreeks bij. Een extra Proxmox-, Forgejo- of algemene shellserver
krijgt daarom nu geen aanbeveling.

## Grenzen van dit onderzoek

De lokale inventarisatie controleerde host, beschikbare opdrachten en
servernamen zonder geheimen over te nemen. De webcontrole gebruikte primaire
projectdocumentatie. De beoordeling van meerwaarde boven CLI's is advies op
basis van die inventarisatie.

Er zijn geen servers geïnstalleerd, databases aangesloten, tokens aangemaakt of
configuraties gewijzigd. MCP-handshakes, browseracties, databaseverbindingen en
clustertoegang zijn tijdens dit onderzoek niet opnieuw getest. Upstream
documentatie kan verder zijn dan de lokaal gepinde pakketten. Dit rapport is
geen audit van de veiligheid of onderhoudskwaliteit van de servercode.

Een algemene filesystem-, git- of shell-MCP en een tweede codeserver zijn
overgeslagen. Voor deze taken bestaan hier al shelltools, Qartez en bestaande
integraties. Nieuwe MCP-aansluitingen kunnen gegevens aan de gebruikte AI-client
doorgeven. Alleen-lezenrechten voorkomen geen uitlekken van leesbare gegevens.
