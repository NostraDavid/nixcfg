# eMudhra CA-incident, bronnenonderzoek op 25 oktober 2026

Onderstaande meetresultaten zijn de uitgangssituatie vóór de reparatie. Zie
[het herstel en de regressietest](python-ca-repair.md) voor de toegevoegde
maatregelen en de commando's voor andere machines en omgevingen.

De configuratie dekt de systeemtruststore, maar beschermt nog niet alle Python-
clients of expliciet gekozen ingebouwde Node-roots. De actieve systeemtrust
weigert de getroffen ketens. De repo-venv en de pip uit de actieve `ensurepip`
accepteren daarentegen een echte TLS-verbinding met een getroffen intermediate.
Er is alleen onderzocht en getest; packages, omgevingen en systeemconfiguraties
zijn niet aangepast.

## Lokaal bewezen dekking en gaten

De bestaande twee blacklistnamen staan nog op alle geëxporteerde NixOS- en
nix-darwin-configuraties. Mimir2 krijgt een gefilterde Home Manager-bundel. De
bestaande `certificateTrust`-architectuurcontrole slaagt. Dat controleert de
configuratie, niet de actieve installatie op iedere machine.

De officiële `chains.zip` bevat veertien ketens, inclusief Sectigo-cross-signs
en twee ketens zonder Certificate Transparency. Deze zijn offline geverifieerd
met OpenSSL, uitsluitend tegen de onderzochte bundle, zonder extra CA-directory
of CA-store. De weigeringen kwamen door ontbrekend of expliciet ingetrokken
vertrouwen, niet door een verlopen certificaat of netwerkfout.

| Onderzocht onderdeel                                          | Geaccepteerde getroffen ketens | Betekenis                                                                                      |
| ------------------------------------------------------------- | ------------------------------ | ---------------------------------------------------------------------------------------------- |
| Actieve Wodan-systeembundel                                   | 0 van 14                       | Bestaande blacklist werkt. Beide interne CA's blijven vertrouwd.                               |
| Gebouwde Mimir2-bundel uit deze configuratie                  | 0 van 14                       | Configuratie werkt; niet op Mimir2 geactiveerd tijdens dit onderzoek.                          |
| Ongewijzigde stable `cacert` 3.126                            | 7 van 14                       | Een client die deze losse store-bundel kiest, omzeilt de hostblacklist.                        |
| Ongewijzigde unstable `cacert` 3.131.1                        | 0 van 14                       | Upstream CA-bundel is voor deze ketens bijgewerkt.                                             |
| Actieve Python 3.13.15, gebundelde pip 26.2.1 uit `ensurepip` | 7 van 14                       | Een nieuwe omgeving kan opnieuw kwetsbare pip meekrijgen.                                      |
| Repo-venv, certifi 2026.6.17                                  | 7 van 14                       | De projectomgeving heeft nog een kwetsbare eigen bundle.                                       |
| Bundles van de vier onderzochte uv-tools                      | Elk 7 van 14                   | `savepagenow`, `specify-cli`, `mistral-vibe` en `huggingface-hub` hebben oude certifi-bundles. |
| Actieve Node 24.21.0, ingebouwde roots                        | 7 van 14                       | Systeemblacklist vervangt Nodes ingebouwde roots niet.                                         |

Daarnaast zijn zeventien pip-bundles in bestaande uv-Python-installaties
onderzocht. Zestien accepteren zeven of veertien getroffen ketens; de bundel van
Python 3.15.1 weigert alle veertien. Dit is een gerichte inventarisatie van de
bestaande uv-runtime-directory, geen inventarisatie van alle omgevingen op de
machine. Bundlevertrouwen bewijst niet dat iedere genoemde applicatie die bundle
ook voor iedere verbinding gebruikt.

De netwerkproef bevestigt het verschil met certificaatcontrole ingeschakeld:

- De standaard Python-systeemcontext weigert beide `noct`-testhosts.
- Pips echte standaard-truststore-context, geladen uit de aanwezige
  `ensurepip`-wheel zonder pip te installeren, accepteert de emSign-`noct`-host.
- Requests in de repo-venv accepteert dezelfde host met HTTP 200.
- De Sectigo-`noct`-host wordt in deze drie gevallen geweigerd.
- Het gezonde controledomein `example.com` werkt in alle drie gevallen.

De actieve Nix-Node 24.21.0 weigert beide `noct`-testhosts met zijn normale
instellingen. Nixpkgs bouwt Node met `--openssl-use-def-ca-store`, waardoor de
systeemtrust standaard wordt gebruikt. Dezelfde binary accepteert de emSign-
testhost met expliciet `--use-bundled-ca`. De oude ingebouwde bundle is dus een
reëel uitwijkpad, maar bewijst geen kwetsbaarheid van de standaard Node-client.

## Vastgezette versies en aanbevolen vervolg

Op de onderzochte revisie gebruiken stable Linux en Darwin `cacert` 3.126,
Python 3.13.15, pip 25.3 en certifi 2026.01.04. Unstable gebruikt `cacert`
3.131.1, Python 3.14.8, pip 26.1.2 en uv 0.13.4. De actieve `ensurepip`-wheel is
apart uitgelezen en bevat pip 26.2.1. Een pakketversie is geen bewijs over alle
meegeleverde wheels of alle actieve omgevingen.

De Nixpkgs-certifi-pakketten zijn gepatcht: hun eigen bundle is een symlink naar
`cacert`, en `NIX_SSL_CERT_FILE` kan die locatie vervangen. Die patch is geen
algemene patch van pips vendored certifi. De blacklist in `security.pki` past
bovendien de hostbundel aan, niet automatisch elke losse `pkgs.cacert`. De
gecontroleerde shell had geen `NIX_SSL_CERT_FILE` of `REQUESTS_CA_BUNDLE` gezet.

Aanbevolen volgorde:

1. Vernieuw de vastgezette Python/pip-combinaties en uv. Gebruik minimaal pip
   26.2.2 en uv 0.13.5, en controleer `ensurepip` afzonderlijk. Verhoog daarna
   de gedeelde uv-`required-version`, die nu nog `>=0.9.0` is. Alleen dat
   minimum verhogen zou de huidige uv 0.13.4 blokkeren zonder een vervanger te
   leveren.
2. Vernieuw pip en certifi in bestaande projectomgevingen en uv-tools, en
   controleer hun lockfiles. Gebruik een veilig geverifieerde bootstrap met de
   officiële wheelhash. Installeer niet blind via een oude kwetsbare pip en
   beschouw `just switch` niet als een upgrade van bestaande virtualenvs.
3. Vernieuw Node 24 naar minimaal 24.22.1 om ook de ingebouwde roots te
   vernieuwen. De gedeelde ontwikkelconfiguratie en enkele lokale MCP-pakketten
   gebruiken Node 24. De huidige Nix-build blokkeert de testhosts standaard al;
   expliciet `--use-bundled-ca` niet. Extra roots toevoegen met
   `NODE_EXTRA_CA_CERTS` trekt de oude ingebouwde roots niet in.
4. Laat Nix-certifi en andere clients de gefilterde hostbundel gebruiken en test
   dat gedrag. `SSL_CERT_FILE`, `NIX_SSL_CERT_FILE` en `REQUESTS_CA_BUNDLE`
   hebben verschillende gebruikers. Presenteer geen van deze variabelen als
   afdoende oplossing voor oude pips standaard-truststore-pad.
5. Voeg een offline ketentest toe aan de bestaande Nix-controles. De huidige
   architectuurtest verifieert namen en configuratie, maar detecteert geen
   kwetsbare vendored bundle. Test naast negatieve ketens ook normale trust.
6. Controleer Loki's systeem-CLI's, containers en ingebouwde applicatieruntimes
   afzonderlijk. Er is hiervoor geen remote toegang gebruikt. Het uitbreiden van
   de blacklist naar certifi's nieuwe C1/C3-intrekkingen is aanvullend beleid;
   de bestaande twee namen blokkeren de oorspronkelijk getroffen ketens al.

De ruwe uitslagen staan voor deze sessie in `/tmp/emudhra-ca-audit/`:
`offline-results.json`, `live-results.json`, `venv-requests-results.json` en
`node-results.json` en `node-live-results.json`. Het gedownloade publieke
testarchief heeft SHA-256
`7b949956955fc501a30f4d98d2f513d34c0bbbe92e29a968194c96e097ce2345`.

De offline controle is te herhalen voor iedere afzonderlijke bundle en iedere
PEM-keten uit
[het officiële archief](https://emudhra.we-have-a-problem.com/chains.zip):

```bash
openssl verify -no-CApath -no-CAstore -purpose sslserver \
  -CAfile /pad/naar/bundle.pem \
  -untrusted /pad/naar/keten.pem /pad/naar/keten.pem
```

`OK` betekent hier dat de getroffen keten nog wordt vertrouwd. Een fout wegens
netwerkbereikbaarheid, een onleesbaar bestand of een verlopen certificaat is
geen bewijs dat de CA geblokkeerd is.

## Gelezen discussie

Alle drie pagina's van de aankondiging zijn gelezen, met 51 zichtbare berichten
tot en met bericht 57 van 25 oktober. Nummergaten komen door verplaatste of
ontbrekende berichten. Ook de afgesplitste discussie met 11 berichten over pip
is gelezen. De aankondiging begon op 20 oktober. De latere berichten bespreken
cross-signing, oude Python-versies, distributiepatches en aanvullende releases.
De verwachting van 23 oktober dat de Python-patch nog moest landen is inmiddels
achterhaald door de merge van 24 oktober.
[Pagina 1](https://discuss.python.org/t/information-for-python-users-regarding-emudhra-emsign-ca-certificate-security-incident/109576),
[pagina 2](https://discuss.python.org/t/information-for-python-users-regarding-emudhra-emsign-ca-certificate-security-incident/109576?page=2),
[pagina 3](https://discuss.python.org/t/information-for-python-users-regarding-emudhra-emsign-ca-certificate-security-incident/109576?page=3),
[afgesplitste discussie](https://discuss.python.org/t/avoiding-compromised-certificates-in-pip/109602).

## Bevestigde fixes en grenzen

| Onderdeel              | Bevestigde fix                                                                | Grens van de fix                                                                                            |
| ---------------------- | ----------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| pip                    | 26.2.2, 20 oktober, bevat certifi 2026.10.19.                                 | Iedere bestaande omgeving heeft haar eigen pip. Een losse certifi-upgrade vervangt pips interne kopie niet. |
| certifi                | 2026.10.19 is het compatibele minimum uit de aankondiging.                    | 2026.10.23 verwijdert aanvullend twee andere emSign-roots.                                                  |
| uv                     | 0.13.4, 20 oktober, vernieuwt de ingebouwde roots.                            | De Python-installaties die uv eerder downloadde veranderen daardoor niet.                                   |
| uv met beheerde Python | 0.13.5, release notes van 21 oktober, gepubliceerd op GitHub op 22 oktober.   | De nieuwe Python-builds moeten ook worden geïnstalleerd. Bestaande virtualenvs vereisen aparte aandacht.    |
| CPython                | 3.15.1, 3.14.9 en 3.13.17, 21 oktober, vernieuwen gebundelde pip naar 26.2.2. | Deze releases vervangen de pip in bestaande virtualenvs niet.                                               |

Bronnen zijn de [pip-changelog](https://pip.pypa.io/en/stable/news/#v26-2-2), de
[certifi-release](https://github.com/certifi/python-certifi/releases/tag/2026.10.19),
de [uv 0.13.4-release](https://github.com/astral-sh/uv/releases/tag/0.13.4), de
[uv 0.13.5-release](https://github.com/astral-sh/uv/releases/tag/0.13.5) en de
[Python-releaseaankondiging](https://discuss.python.org/t/python-3-15-1-3-14-9-and-3-13-17-are-out/109595).

De certifi-update van 23 oktober verwijdert `emSign Root CA - C1` en
`emSign ECC Root CA - C3`. Dat is een verdere intrekking van vertrouwen, geen
aanwijzing dat 2026.10.19 de oorspronkelijk getroffen ketens bleef vertrouwen.
Het is ook geen volledige verwijdering van alle emSign-roots.
[Exacte wijziging](https://github.com/certifi/python-certifi/commit/b60466c9f2882d9cf088943c650b0faac06c080c).

uv 0.13.5 gebruikt python-build-standalone 20261021 voor Python 3.11 en nieuwer.
Die builds vernieuwen zowel geïnstalleerde pip als de wheel in `ensurepip`. Een
vastgezette oudere Python-patchversie schakelt niet automatisch over. Een
nieuwere uv-binary alleen is daarom onvoldoende bewijs voor de veiligheid van
`python -m venv` of een bestaande omgeving.
[uv-releasevoorwaarden](https://github.com/astral-sh/uv/releases/tag/0.13.5).

## Systeemcertificaten en cross-signing

Standaard pip gebruikt de systeemcertificaten samen met de eigen certifi-bundle.
`PIP_CERT`, `REQUESTS_CA_BUNDLE` of `--cert` alleen schakelen die eigen bundle
niet betrouwbaar uit. De pip-maintainers bevestigen als tijdelijke omweg
`PIP_USE_DEPRECATED=legacy-certs` samen met `PIP_CERT` naar een veilige bundle.
Omgevingsvariabelen zijn nodig om ook build-subprocessen te bereiken. Een
actuele pip heeft de voorkeur boven deze tijdelijke omweg.
[pip-documentatie](https://pip.pypa.io/en/stable/topics/https-certificates/),
[uitleg en correcties van de maintainers](https://discuss.python.org/t/avoiding-compromised-certificates-in-pip/109602).

De getroffen TLS-intermediates hebben ook een Sectigo-keten naar
`AAA Certificate Services`. Alleen `emSign ECC Root CA - G3` verwijderen sluit
die route niet. Ook oude bundles kunnen deze Sectigo-root bevatten. De
incidentwebsite noemt voor NixOS beide blacklistnamen `Comodo AAA Services root`
en `emSign ECC Root CA - G3`. Een geweigerde verbinding wegens een netwerkfout
bewijst geen certificaatblokkade. De website biedt ook offline certificaatketens
voor gerichte verificatie.
[Incidentwebsite, gepubliceerd 20 oktober en later bijgewerkt](https://emudhra.we-have-a-problem.com/).

Apple bevestigt op 23 oktober dat sommige systeem-CLI's, waaronder curl, git en
Python, `/etc/ssl/cert.pem` blijven gebruiken zonder Apples bloklijst. Een
bijgewerkt Safari bewijst dus niets over die CLI's. Apple noemt het verwijderen
van beide roots als tijdelijke optie en waarschuwt dat legitieme sites daardoor
kunnen uitvallen. Een macOS-update kan dit bestand vervangen. Nix-gereedschappen
met een eigen bundle vereisen een afzonderlijke controle.
[Apple Support](https://support.apple.com/en-us/149555).

## Nieuwe bescherming in runtimes

CPythons SPKI-blokkade is op 24 oktober gemerged. Deze blokkeert de getroffen
publieke sleutels, ook bij cross-signing. De backports voor 3.11 en 3.12 zijn
diezelfde dag gemerged. Een merge is geen bewijs van een gepubliceerde release
of van opname in de hier vastgezette Nixpkgs. De Python-releases van 21 oktober
dateren van vóór deze merge.
[Hoofdpatch](https://github.com/python/cpython/pull/160042),
[3.11-backport](https://github.com/python/cpython/pull/160572),
[3.12-backport](https://github.com/python/cpython/pull/160571).

Go 1.27.3 en 1.26.10 bevatten sinds 19 oktober een intermediate-blokkade.
`rustls-webpki` 0.103.16 blokkeert sinds 20 oktober getroffen publieke sleutels.
`webpki-roots` en `webpki-root-certs` 1.0.10 verwijderen de getroffen
emSign-root. Voor statisch gebouwde programma's vereist een nieuwe runtime of
library een nieuwe build van het programma. Alleen de compiler installeren
verandert een bestaande binary niet.
[Go-securityrelease](https://groups.google.com/g/golang-announce/c/66pojueaQek),
[rustls-webpki](https://github.com/rustls/webpki/releases/tag/v%2F0.103.16),
[webpki-roots](https://github.com/rustls/webpki-roots/releases/tag/v%2F1.0.10).

Node 22.23.4, 24.22.1 en 26.12.1 vernieuwen op 21 oktober de roots naar NSS
3.131.1. Electron 44.9.1 noemt op 20 oktober expliciet de eMudhra-fix. Mise
2026.10.17, gepubliceerd op 21 oktober, verwijdert eveneens het getroffen
vertrouwen. GitHub CLI 2.102.1, 20 oktober, vernieuwt de ingebouwde Go-toolchain
naar 1.27.3. Dit zijn controlepunten voor de geïnstalleerde applicaties.
[Node 22](https://github.com/nodejs/node/releases/tag/v22.23.4),
[Node 24](https://github.com/nodejs/node/releases/tag/v24.22.1),
[Node 26](https://github.com/nodejs/node/releases/tag/v26.12.1),
[Electron](https://github.com/electron/electron/releases/tag/v44.9.1),
[Mise](https://github.com/jdx/mise/releases/tag/v2026.10.17),
[GitHub CLI](https://github.com/cli/cli/releases/tag/v2.102.1).

## Advies voor de configuratiecontrole

Dit zijn afgeleide controlepunten, geen verklaring dat alles al is uitgerold:

1. Controleer beide relevante roots in de daadwerkelijk gebruikte CA-bundles.
   Controleer NixOS en nix-darwin afzonderlijk.
2. Controleer pip, losse certifi en `ensurepip` afzonderlijk. Neem virtualenvs,
   uv-tools en ingebouwde Python-installaties mee.
3. Controleer bij uv ook de geïnstalleerde Python-builds. Houd beveiligingsfixes
   buiten eventuele automatische wachttijden voor nieuwe dependencies.
4. Controleer vastgezette dependencies en containerimages. Vernieuw de
   basisimage en bouw zonder oude installatielagen opnieuw. Het
   hostcertificaatbestand vernieuwt een onafhankelijke containerbundle niet.
5. Controleer statische Go- en Rust-programma's en de runtimes van Electron-apps
   afzonderlijk. Een nieuwe systeemtruststore dekt ingebouwde bundles niet.
6. Gebruik bij verbindingstests een gezonde controledomeinnaam en controleer de
   certificaatfout. Gebruik geen `--insecure` of `--trusted-host` als fix.

Er is voor dit bronnenonderzoek geen deployment uitgevoerd, geen macOS-bestand
aangepast en geen bestaande virtualenv gemuteerd. Applicaties buiten Nix en oude
omgevingen blijven afzonderlijke controlepunten.
