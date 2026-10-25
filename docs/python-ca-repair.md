# Python-certificaten herstellen na het eMudhra-incident

De configuratie filtert de getroffen roots op NixOS, nix-darwin en standalone
Home Manager. Ze filtert ook de losse Nix-CA-bundel waar Nix-certifi op
terugvalt. De interne CA's van NixOS blijven in de hostbundel staan.

Vanaf NSS 3.131.1 gebruikt die losse bundel het ongewijzigde upstream-pakket,
zodat de officiële binary cache bruikbaar blijft. NSS weigert de getroffen
servercertificaten zelf. De AAA-root houdt upstream nog vertrouwen voor e-mail;
de expliciete blacklist in de systeem- en standalone Home Manager-bundels blijft
deze root volledig verwijderen. Oudere NSS-bundels houden de lokale filtering.

Het lokale pakket `pkgs/uv` levert uv 0.13.5 of nieuwer. Bijwerken kan met
`just pkg-update uv`. De gerichte backports in `nix/ca-security.nix` leveren pip
26.2.2 en Node 24.22.1. De gebruikerscommando's `~/.local/bin/python` en
`~/.local/bin/python3` gebruiken een kopie van de bestaande Nix-interpreter.
Alleen diens `ensurepip` krijgt de geverifieerde pip-wheel 26.2.2 wanneer de
meegeleverde versie ouder is. Python wordt daarvoor niet opnieuw gecompileerd.
De Python-interpreters voor builds blijven ongewijzigd, zodat deze CA-fix niet
alle afhankelijke compilers en pakketten opnieuw laat bouwen. De ingebouwde
pip-wheels van `virtualenv` worden afzonderlijk gefilterd. Nieuwere
upstream-versies worden niet door een oudere backport vervangen.

## Activeer de configuratie

Voer op iedere machine de normale configuratie-activatie uit:

```bash
just switch
```

Start daarna een nieuwe sessie voor programma's die hun omgevingsvariabelen bij
het starten lezen. Home Manager verwijdert tijdens activatie de getroffen roots
uit bestaande uv-Python-installaties, uv-tools en de `.venv` van deze
configuratierepository. Dit start geen netwerkdownload.

Op macOS filtert de systeemactivatie ook `/etc/ssl/cert.pem`. Apples native
CLI-programma's kunnen dat bestand gebruiken, ook wanneer een omgevingsvariabele
door `sudo` wordt verwijderd. Het herstel bewaart andere certificaten en maakt
een volledige `.before-emudhra`-back-up vóór de eerste wijziging.

`SSL_CERT_FILE`, `NIX_SSL_CERT_FILE`, `REQUESTS_CA_BUNDLE`, `CURL_CA_BUNDLE`,
`GIT_SSL_CAINFO` en `PIP_CERT` verwijzen naar de bijbehorende gefilterde bundel.
`SSL_CERT_DIR` wijst naar een lege Nix-directory, zodat OpenSSL niet alsnog
ongefilterde certificaten uit een andere standaarddirectory toevoegt. Pip en
zijn vendored bundels worden zelf gerepareerd; alleen `PIP_CERT` instellen is
geen afdoende reparatie. De globale optie `legacy-certs` wordt niet gebruikt:
oudere pip-versies herkennen die optie niet.

Alle dotfiles blijven direct naar de live checkout gesymlinked. De uv-dotfile
vereist minimaal 0.13.5; de beheerde `uv`- en `uvx`-launchers leveren die
versie.

De Homepage-service gebruikt eveneens de gefilterde hostbundel. Node gebruikt
daarin expliciet OpenSSL-certificaten. Activeer daarvoor ook de bijgewerkte
configuratie van de betreffende VM.

## Controleer bestaande projectomgevingen

Een configuratie-activatie vernieuwt niet automatisch iedere oude projectvenv.
Controleer vertrouwde omgevingsmappen expliciet. Paden met spaties werken ook:

```bash
just python-ca-audit "$HOME/dev/project/.venv"
just python-ca-repair "$HOME/dev/project/.venv"
just python-ca-audit "$HOME/dev/project/.venv"
```

De audit schrijft niets en geeft een niet-nul exitcode als herstel nodig is. Het
herstel verwijdert alleen de vier roots op basis van hun DER-SHA-256, niet op
basis van een tekstlabel. Het behoudt andere publieke en private CA's,
bestandsrechten en pip-wheelinhoud. Gewijzigde bestanden worden atomair
vervangen; installatie-RECORD's krijgen de nieuwe hashes en groottes.

Het hulpmiddel voert geen pip of Python uit de onderzochte omgeving uit. Het
werkt ook voor oude Python-versies die een recente pip niet ondersteunen. Dit is
een gerichte CA-backport, geen algemene beveiligingsupdate van een oude Python-
of pip-release. Projectcode, dependencyversies en lockfiles veranderen niet.

Nix-storebestanden en symlinks worden niet overschreven. Directorysymlinks
worden niet gevolgd. Een fout of onleesbare map geeft een niet-nul exitcode. Een
tweede uitvoering hoort `Pending: 0; failures: 0` te tonen. De eerste back-ups
worden bij een herhaling niet overschreven.

Vernieuw daarnaast waar mogelijk de uv-runtimebuilds:

```bash
uv python upgrade
```

Dit vervangt geen expliciet vastgezette oude interpreter in iedere venv. Houd
pip en certifi in project-lockfiles actueel, zodat een herbouw geen oude bundels
terugbrengt. Controleer afzonderlijke containerimages en applicatiebundels bij
hun eigen updateproces; een hostactivatie wijzigt die images niet.

## Voer de regressietest uit

```bash
just certificate-trust-check
```

De Nix-check gebruikt het vaste officiële archief met veertien getroffen ketens,
inclusief Sectigo-cross-signs en twee ketens zonder Certificate Transparency. De
oorspronkelijke oude bundel moet ze accepteren, en de gerepareerde en beheerde
bundels moeten ze weigeren. De test gebruikt een vast verificatietijdstip voor
deze fixtures, zodat verlopen testcertificaten geen schijnbescherming geven.

De check onderzoekt ook geïnstalleerde pip, `ensurepip`, nieuwe `venv`- en
`virtualenv`-omgevingen, normale interne trust, herstelmetadata, een onderbroken
back-up en herhaalde uitvoering. Ze controleert de werkelijke truststore-context
van nieuw geïnstalleerde pip en bewaakt dat de CA-overlay de bouwinterpreter en
Rust-toolchain niet verandert. De pre-commithook voert dezelfde check uit bij
relevante wijzigingen.

Het [bronnenonderzoek](emudhra-ca-incident-research.md) bevat de oorspronkelijke
bevindingen, upstream-adviezen en de grenzen van de lokale inventarisatie.
