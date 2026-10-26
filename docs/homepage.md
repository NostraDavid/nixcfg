# Homepage

De startpagina staat op <https://home.powerlan.empire/>. Homepage draait als
native NixOS-dienst op VM 103, `prd-svc-homepage-01`, op `192.168.2.103`. De
proxy op `192.168.2.111` verzorgt de HTTPS-ingang.

`features/homepage/default.nix` beheert de software, links, widgets en inhoud.
`hosts/virtual/homepage/default.nix` neemt deze feature op.
`hosts/virtual/proxy/default.nix` beheert de HTTPS-ingang. De NixOS-module
schrijft de configuratie naar `/etc/homepage-dashboard`. Er is geen aparte
database of handmatig bewerkte YAML nodig.

## Links en widgets

De pagina bevat Proxmox, Pi-hole, FreeIPA, Forgejo, OpenBao, Home Assistant, het
certificatenportaal. De actieve diensten krijgen een bereikbaarheidscontrole.
Die controle bewijst dat de website reageert; zij test geen aanmelding of
achterliggende functie.

De bovenste widgets tonen CPU, geheugen en uptime van de Homepage-VM, plus de
datum en tijd in RFC 3339, inclusief seconden en de Amsterdamse UTC-offset. De
kleine formatter in `features/homepage/rfc3339-clock.js` past alleen de
scheidingstekens van de bestaande klok aan; `Intl` bepaalt zomer- en wintertijd.
Dit zijn geen Proxmox-hoststatistieken. Homepage's
[dienstcontroles](https://gethomepage.dev/configs/services/#site-monitor) hebben
geen beheersleutel nodig.

De Proxmox-widget toont CPU, geheugen en actieve VM's van POwerMonolith. Hij
gebruikt `homepage@pve!dashboard` met uitsluitend `Sys.Audit` en `VM.Audit`.
Privilege separation blijft aan. De Pi-hole-widget gebruikt de v6-API voor
DNS-verzoeken, geblokkeerde verzoeken en het blokkeerpercentage. Het
appwachtwoord heeft geen recht om de Pi-hole-configuratie te wijzigen.

Pi-hole biedt geen afzonderlijke API-rol voor uitsluitend statistieken. De
widget toont alleen totalen; zijn appwachtwoord heeft bredere API-rechten,
waaronder lijstbeheer. Configuratiewijzigingen blijven uitgeschakeld.

De API-geheimen staan in OpenBao onder `services/data/homepage/proxmox` en
`services/data/homepage/pihole`. De eigen AppRole van Homepage is beperkt tot VM
103 en deze twee geheimen, plus de vier benodigde status- en rotatiepaden. De
AppRole mag geen LDAP-wachtwoorden lezen. Bootstrapgegevens staan met mode
`0600` in `/var/lib/homepage-monitor/approle.json`. De minuuttaak maakt een
beschermd omgevingsbestand in `/run/homepage-monitor/credentials.env` en
herstart Homepage alleen als zijn widgetgeheimen veranderen. Geheimen staan niet
in Git of de Nix-store.

Home Assistant gebruikt `https://homeassistant.powerlan.empire/`. Alle links
gebruiken HTTPS. De ongebruikte Passvault op VM 107 is buiten gebruik gesteld;
OpenBao op VM 112 is de actieve kluis. Zie
[HTTPS voor de bestaande diensten](service-https.md).

Iedere website toont zijn HTTPS-status en resterende geldigheid. De kaart
Certificaten toont ook de Homepage-ingang en de bestaande Pi-hole-vernieuwing.
Een TLS-fout krijgt `Fout`; bij minder dan dertig dagen verschijnt `Vernieuwen`.
De controles gebruiken normale hostnaam- en CA-validatie.

De Pi-hole-kaart controleert daarnaast een echte DNS-query aan `192.168.2.102`
en vergelijkt het antwoord voor `home.powerlan.empire` met de verwachte proxy.
De FreeIPA-kaart gebruikt de bestaande, echte LDAP-binds van `forgejo-reader` en
`proxmox-reader`. Beide afnemers bevestigen hun bind en applicatiecontrole
iedere minuut aan OpenBao. Een bevestiging ouder dan vijf minuten is fout. De
OpenBao-kaart toont of beide dagelijkse rotaties op tijd zijn.

De kaart Kluisback-up toont de versleutelde kopie buiten Proxmox op Wodan. Wodan
publiceert iedere vijf minuten alleen de laatste back-uptijd en het resultaat
van zijn bestaande back-updienst. Homepage accepteert geen rapport ouder dan
vijftien minuten of back-up ouder dan twee uur. Wodan moet aanstaan voor actuele
rapportage en voor de back-ups die daarheen worden gekopieerd. Een onbekende of
oude meting wordt niet als gezond voorgesteld. Een kopie telt pas mee nadat de
onafhankelijke herstelsleutel haar heeft ontsleuteld.

`scripts/homepage-monitor.py` verzamelt deze gegevens iedere minuut. Alleen
lokale processen kunnen de status-API op `127.0.0.1:3001/status.json` opvragen.
De API serveert geen andere bestanden en weigert gegevens ouder dan drie
minuten. De browser krijgt alleen de samenvatting; API-geheimen en
wachtwoordhashes worden niet gepubliceerd. Alle diensticonen komen van `/icons/`
op de eigen proxy en hebben tijdens gebruik geen externe CDN nodig.

## Netwerk en certificaten

Pi-hole moet dit lokale DNS-record bevatten:

```text
192.168.2.111 home.powerlan.empire
```

Dit record staat in de bestaande Pi-hole-configuratie buiten NixOS. De
applicatie en haar inhoud staan volledig in Nix. Caddy vraagt certificaten aan
bij de certificaten-VM op `192.168.2.113` en verzorgt HTTPS en de HTTP-redirect.
Apparaten moeten het [interne certificaatvertrouwen](internal-pki.md) hebben.

Homepage luistert op poort 3000. De firewall laat alleen de proxy op
`192.168.2.111` toe. Caddy biedt de pagina via HTTPS op het LAN aan. Node
gebruikt de gefilterde systeemcertificaten en vertrouwt ook het bestaande
Proxmox-certificaat voor rechtstreeks beheer op het IP-adres. De Homepage-link
gebruikt nu [de Proxmox-URL](proxmox-web.md); Caddy controleert de backend met
de vastgelegde Proxmox-cluster-CA.

## Bijwerken en controleren

Pas de lijsten onder `services.homepage-dashboard` aan en voer op Wodan uit:

```bash
just homepage-monitor-test
just app-vm-check homepage
just deploy-homepage
just deploy-proxy
```

Controleer daarna de echte website, inclusief de bereikbaarheidsmeldingen:

```bash
dig @192.168.2.102 home.powerlan.empire +short
curl --fail --cacert certs/forgejo-ca.crt https://home.powerlan.empire/
ssh david@192.168.2.103 systemctl is-active homepage-dashboard
ssh david@192.168.2.111 systemctl is-active caddy
ssh david@192.168.2.103 systemctl status homepage-monitor.timer
systemctl --user status homepage-backup-report.timer
```

Een herstart gebruikt dezelfde Nix-configuratie. Homepage's cache mag
verdwijnen. De CA en certificaatstate staan op de certificaten-VM. Zie de
[VM-indeling en migratie](service-vm-split.md) voor het behoud van die state.

## Grenzen en gecontroleerde werking

De widgetgeheimen van Proxmox en Pi-hole worden nog niet automatisch vernieuwd.
Een wijziging in OpenBao wordt binnen een minuut overgenomen. De bestaande
dagelijkse LDAP-wachtwoordrotatie blijft zelfstandig werken.

Op 25 oktober 2026 zijn de echte Proxmox- en Pi-hole-statistieken, alle
geconfigureerde HTTPS-controles, DNS-antwoorden, LDAP-bevestigingen en de
off-host back-upstatus gecontroleerd. De effectieve Proxmox-rechten zijn precies
`Sys.Audit` en `VM.Audit`. De Homepage-AppRole kreeg HTTP 403 bij het opvragen
van beide LDAP-geheimen en van de OpenBao-beheerpolicy.

Een volledige VM-herstart heeft bevestigd dat Homepage zijn geheimen zelf
opnieuw ophaalt. De runtimebestanden hebben mode `0600`; de openbare API en logs
bevatten geen widgetgeheimen. De lokale status-API weigert andere bestandspaden
en oude gegevens. `just homepage-monitor-test` bevat zeven tests voor deze
grenzen. Pi-hole heeft de nieuwe appinstelling zonder herstart geladen; DNS en
het bestaande beheerderswachtwoord zijn behouden.
