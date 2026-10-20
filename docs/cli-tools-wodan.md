# CLI-tools die wodan nog kunnen helpen

Onderzocht op 20 oktober 2026. Wodan heeft al een brede toolkit. Mijn eerste
keuze is `nix-locate` met een vooraf gebouwde index. Daarna volgen `nvd` voor
updates en `actionlint` voor de bestaande GitHub Actions-workflow. Andere
kandidaten zijn nuttig bij een concrete taak. Dit is advies, geen
installatieplan.

## Wat al beschikbaar of gedeclareerd is

De actieve PATH bevat onder meer `hyperfine`, `difft`, `dust`, `xh`, `nom`,
`viddy`, `procs`, `k9s`, `gh`, `uv` en `devenv`. De gebruikelijke zoek-,
formatteer- en shelltools zijn ook aanwezig. `ncdu`, `mtr`, `dig` en `btop`
dekken schijfruimte, routes, DNS en procesgebruik al af.

`watchexec` en `doggo` ontbreken in deze PATH, maar staan al in de optionele
workstationmodules. Dat is een verschil tussen profiel en actieve omgeving, geen
ontbrekend pakket in de repository.
[Bronnen: developmentprofiel](../modules/home/workstation/development/core.nix)
en [netwerkprofiel](../modules/home/workstation/terminal/network.nix). Ook Hurl
is al gedeclareerd in [portable-cli.nix](../modules/home/portable-cli.nix). Het
ontbreken van een opdracht in deze sessie bewijst niet dat een extra declaratie
nodig is.

## De gerichte shortlist

### nix-index met nix-index-database

`nix-locate` zoekt welk Nix-pakket een bepaald bestand bevat. Dat helpt wanneer
een binary of gedeelde bibliotheek ontbreekt terwijl je de pakketnaam niet kent.
Dit verschilt van zoeken op pakketnaam met `nix search`.
[Bron: nix-index](https://github.com/nix-community/nix-index).

`nix-index-database` levert een wekelijks bijgewerkte index voor nixos-unstable
en modules voor NixOS en Home Manager. Daardoor hoeft wodan de index niet zelf
te bouwen. Voor bibliotheken is de volledige database nodig. De kleine variant
bevat alleen bestanden onder `bin`.
[Bron: nix-index-database](https://github.com/nix-community/nix-index-database).
De gevonden pakketten moeten nog worden gecontroleerd tegen jouw gepinde
nixpkgs-revisie. Dit is mijn sterkste algemene aanvulling.

### nvd

`nvd` vergelijkt pakketversies tussen twee Nix-closures. Dat geeft bij een
systeemupdate een begrijpelijke lijst van pakketveranderingen.
[Bron: aankondiging van de auteur](https://discourse.nixos.org/t/nvd-simple-nix-nixos-version-diff-tool/12397).

Het past hier bij het beoordelen van een nieuwe systeemgeneratie vóór activatie.
De aanwezige `nom` helpt tijdens builds, maar beantwoordt een andere vraag. De
auteurbron bevestigt de kernfunctie. De actuele upstreamrepository kon tijdens
dit onderzoek niet worden uitgelezen, dus recente opties en onderhoudsstatus
zijn niet bevestigd.

### actionlint

Deze repository heeft een echte
[GitHub Actions-workflow](../.github/workflows/validate.yml). `actionlint`
controleert workflowsyntax, expressietypes, actiongebruik en
jobafhankelijkheden. Het kan de aanwezige ShellCheck gebruiken voor ingebedde
shellcode. [Bron: actionlint](https://github.com/rhysd/actionlint).

Dat vult de bestaande Nix-, YAML- en shellchecks gericht aan. Een YAML-parser
controleert bijvoorbeeld niet of een Actions-expressie een geldige context
gebruikt. Bij een latere invoering past deze tool in de bestaande projectchecks,
zonder een aparte controleworkflow te ontwerpen.

### nix-tree

`nix-tree` laat je interactief door Nix-afhankelijkheden bladeren. Het toont
onder meer closuregrootte en de extra grootte van unieke afhankelijkheden en
heeft een weergave voor `why-depends`.
[Bron: nix-tree](https://github.com/utdemir/nix-tree).

Voor deze repository is dat nuttig wanneer een pakket onverwacht veel
afhankelijkheden meetrekt. De meerwaarde boven losse `nix path-info`- en
`nix why-depends`-opdrachten zit in herhaald verkennen. Voor één bekende
afhankelijkheidsvraag volstaat Nix zelf. Daarom krijgt dit minder prioriteit dan
de index en de workflowcheck.

### lnav

`lnav` herkent logformaten, indexeert logbestanden tijdens het openen en biedt
filters en een SQLite-interface voor analyse.
[Bron: lnav-handleiding](https://docs.lnav.org/en/latest/intro.html).

Dit wordt nuttig bij lang onderzoek naar lab- of applicatielogs met meerdere
velden en terugkerende patronen. Voor één foutregel zijn `journalctl` en `rg`
voldoende. Of de concrete lablogformaten automatisch goed worden herkend, is
niet getest. Begin daarom met één representatief logbestand voordat je het als
vast onderdeel van de toolkit beschouwt.

### watchexec uit het bestaande profiel

`watchexec` voert opdrachten uit na bestandswijzigingen en kan processen
herstarten. Upstream documenteert extensiefilters en gebruik met `just`.
[Bron: watchexec](https://github.com/watchexec/watchexec).

Voor een herhaalbare controle tijdens het bewerken is dat bruikbaarder dan
steeds dezelfde opdracht typen. `viddy` is er al voor periodieke inspectie.
Omdat watchexec al gedeclareerd is, vraagt dit eerst onderzoek naar het gekozen
profiel. Een bestaande watcher van het project blijft de eerste keuze.

## Wat ik oversla

`dua`, `bottom`, `trippy` en `doggo` krijgen geen eerste prioriteit omdat er al
bruikbare schijf-, proces- en netwerktools zijn. `mise` voegt hier een tweede
route toe naast Nix, devenv en direnv. Ook een extra algemene diffviewer heeft
weinig nut naast de aanwezige alternatieven. Deze afweging gaat over toegevoegde
waarde op wodan, niet over de kwaliteit van die projecten.

Er is niets geïnstalleerd of geconfigureerd. De controle combineert PATH en
repositorydeclaraties met primaire bronnen. De kandidaten zijn niet lokaal
uitgevoerd of gebenchmarkt. Beschikbaarheid in de exact gepinde package sets en
het downloadvolume moeten vóór eventuele toevoeging nog worden nagegaan.
