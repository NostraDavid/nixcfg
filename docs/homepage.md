# Homepage

De startpagina staat op <https://home.powerlan.empire/>. Homepage draait als
native NixOS-dienst op een aparte VM op `192.168.2.114`. De proxy op
`192.168.2.111` verzorgt de HTTPS-ingang.

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

Proxmox- en Pi-hole-API-widgets zijn niet ingesteld. Gebruik daarvoor later
aparte, beperkt bevoegde API-toegang en beschermde runtimebestanden via
`services.homepage-dashboard.environmentFiles`. Zet geen tokens in Nix-waarden
of Git. Zie de
[Proxmox-widget](https://gethomepage.dev/widgets/services/proxmox/).

Home Assistant gebruikt `https://homeassistant.powerlan.empire/`. Alle links
gebruiken HTTPS. De ongebruikte Passvault op VM 107 is buiten gebruik gesteld;
OpenBao op VM 112 is de actieve kluis. Zie
[HTTPS voor de bestaande diensten](service-https.md).

De kaart Certificaten onder Beheer toont de Pi-hole-certificaatstatus,
resterende geldigheid en laatste controle. Hiervoor zijn geen API-sleutels
nodig. De gegevens bevatten geen geheimen en komen van de
[certificaatbewaking](pihole-https.md). De kaart en haar statusgegevens
gebruiken <https://certs.powerlan.empire/>.

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
just app-vm-check homepage
just deploy-homepage
```

Controleer daarna de echte website, inclusief de bereikbaarheidsmeldingen:

```bash
dig @192.168.2.102 home.powerlan.empire +short
curl --fail --cacert certs/forgejo-ca.crt https://home.powerlan.empire/
ssh david@192.168.2.114 systemctl is-active homepage-dashboard
ssh david@192.168.2.111 systemctl is-active caddy
```

Een herstart gebruikt dezelfde Nix-configuratie. Homepage's cache mag
verdwijnen. De CA en certificaatstate staan op de certificaten-VM. Zie de
[VM-indeling en migratie](service-vm-split.md) voor het behoud van die state.
