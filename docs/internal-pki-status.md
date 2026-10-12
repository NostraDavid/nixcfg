# Uitrol van interne CA's op 12 oktober 2026

Deze inventaris beschrijft uitgevoerde controles. Niet-bereikbare apparaten zijn
niet als getest aangemerkt. Installatie en herhaalde controles staan in
[Interne certificaten vertrouwen](internal-pki.md).

## Geverifieerde CA's

De SSH-hostsleutels van VM 110 en 111 zijn vergeleken met de ingelogde
Proxmox-console. De publieke Forgejo-CA is via geverifieerde SSH opgehaald. De
SHA-256-certificaatfingerprint is onafhankelijk via Proxmox vergeleken. De
FreeIPA-CA is ongewijzigd verplaatst uit de Wodan-map naar `certs/`. Beide
bestanden hebben checksums en certificaatfingerprints in die map.

## Bereikbare machines

De pagina biedt ook een volledige ZIP en een PEM-bundel met versie `1.0.0` aan.
De SemVer-versie staat in `certs/VERSION`, `version.txt` en in de vaste
release-URL. `powerlan-ca-latest.zip` en `powerlan-ca-latest.pem` verwijzen naar
die release. Oude releases blijven op de persistente proxydisk bewaard.
`just internal-pki-bundle-check` controleert de ZIP-inhoud, beide PEM-CA's,
checksums, cache-instellingen en het echte archiefscript bij herhaling, bij het
weigeren van gewijzigde inhoud onder dezelfde versie en bij het publiceren onder
een nieuwe versie. De archieftests gebruiken tijdelijke mappen; er zijn geen
fictieve releases op de proxy gepubliceerd.

De downloadpagina op <http://192.168.2.111/> biedt beide publieke CA's,
fingerprints en bestandschecksums aan. De geteste downloads zijn byte voor byte
gelijk aan de repo-bestanden. Een verzoek om `root.key` geeft HTTP 404.
Desktopweergave en een mobiele viewport van 390 pixels zijn in Chrome
gecontroleerd; er is geen horizontale overflow. De Forgejo-healthcheck blijft
slagen. Herhaal de downloadcontrole met `just internal-pki-site-check`.

| Machine           | Platform                   | Uitgevoerd                                                                                  | Resultaat                                                                                        |
| ----------------- | -------------------------- | ------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------ |
| Wodan             | NixOS                      | CA-module en volledige generatie gebouwd; actieve generatie en opstartprofiel gecontroleerd | Beide CA's vertrouwd; HTTPS-healthcheck en normale Git-clone zonder CA-overrides slagen.         |
| Proxmox-host .100 | Debian, Proxmox            | Beide CA's geïnstalleerd                                                                    | Forgejo-HTTPS en LDAPS via systeemopslag slagen.                                                 |
| VM 101            | FreeIPA                    | LDAPS en de HTTPS-beheerinterface met de centrale FreeIPA-CA gecontroleerd                  | Beide TLS-controles slagen; webinterface geeft HTTP 200. Guest agent niet actief.                |
| VM 102            | Debian 12, Pi-hole         | Beide CA's geïnstalleerd; nslcd naar gecontroleerde StartTLS omgezet                        | HTTPS, LDAP-opzoeking na herstart en afwijzing verkeerde hostnaam slagen.                        |
| VM 104            | Debian 12, datavault       | Beide CA's geïnstalleerd; nslcd naar gecontroleerde StartTLS omgezet                        | HTTPS, LDAP-opzoeking na herstart en afwijzing verkeerde hostnaam slagen.                        |
| VM 107            | Debian 12, Vault           | Beide CA's geïnstalleerd                                                                    | Forgejo-HTTPS via systeemopslag slaagt. Geen Docker of Podman gevonden. Vault-login niet getest. |
| VM 108            | Windows 10 Enterprise LTSC | Alleen OS-inventaris via guest agent                                                        | Buiten de opgegeven platformscope; niet gewijzigd.                                               |
| VM 109            | Home Assistant OS 18.3     | Docker-images en beschikbare LDAP-configuratie geïnventariseerd                             | Geen LDAP-verwijzingen gevonden bij de gerichte zoekactie. Geen CA-wijziging uitgevoerd.         |
| VM 110            | NixOS, Forgejo             | Nieuwe systeemgeneratie geactiveerd                                                         | Forgejo, PostgreSQL en Caddy actief; HTTPS via systeemopslag slaagt.                             |
| VM 111            | NixOS, proxy               | Nieuwe systeemgeneratie geactiveerd                                                         | Caddy actief; HTTPS via systeemopslag slaagt.                                                    |

Op Debian staan de CA's onder `/usr/local/share/ca-certificates/powerlan/`. De
bestaande publieke CA's en eerder geïnstalleerde lokale certificaten zijn
behouden. Het bestaande bestand `ldap-ca.crt` op VM 102 en 104 veroorzaakt een
rehash-waarschuwing doordat het meer dan één certificaat bevat. De nieuwe
CA-bestanden bevatten elk één certificaat; de verbindingstests slagen.

De nslcd-back-ups op VM 102 en 104 staan lokaal onder
`/etc/nslcd.conf.before-internal-pki.*`, met behoud van de oorspronkelijke
toegangsrechten. De bindinstellingen zijn niet gewijzigd of naar deze repo
gekopieerd. Beide clients gebruiken nu `ssl start_tls`, `tls_reqcert demand` en
`/etc/ssl/certs/ca-certificates.crt`.

## Containers en niet-bereikbare apparaten

- De 21 lokale Podman-containers op Wodan waren gestopt. Hun omgevingsvariabelen
  bevatten geen LDAP- of StartTLS-instellingsnamen. Applicatiespecifieke
  configuratie en toekomstige images blijven apart te controleren; dit is geen
  bewijs dat iedere container LDAP-vrij is.
- VM 109 draait Home Assistant en add-ons, waaronder Mosquitto en Zigbee2MQTT.
  De echte configuratiepaden zijn via Docker-mounts vastgesteld. De gerichte
  zoekactie omvat `homeassistant`, `app_configs` en `apps/data` onder
  `/mnt/data/supervisor/`. Er is geen LDAP-container geïdentificeerd waarvoor
  een imagewijziging kon worden uitgevoerd en getest.
- VM 103, 105, 106, 210 en 211 stonden uit. Ze zijn niet gestart of gewijzigd.
- Frigg, Donar en Bragi konden via hun bestaande hostnamen niet worden opgelost.
  De gedeelde NixOS-module geldt ook voor deze configuraties; activatie en
  verbindingstests staan nog open.
- Android is niet op afstand verbonden. CA-installatie en browser- en
  appcontroles moeten op het toestel gebeuren. Er is nog geen specifieke app als
  ondersteund of niet ondersteund vastgesteld.

## Openstaande controles

Wodan is tijdens de gedeelde build door een parallelle systeemactivatie
bijgewerkt. De actieve generatie en het opstartprofiel verwijzen beide naar
`409vb25w9vihfmy1nkaka4pp910jwkxl-nixos-system-wodan-26.05.20261010.6fcc160`.
Beide centrale CA's zijn tegen de werkelijke systeemopslag geverifieerd. De
Forgejo-healthcheck en de normale Git-clone slagen zonder CA-overrides. De
testrepository is leeg. Er is geen tweede systeemactivatie uitgevoerd.

De eigen volledige Wodan-build slaagde eveneens. De bestaande openstaande
systeem- en pakketwijzigingen zijn in de geactiveerde generatie meegenomen.

De bestaande `just forgejo-ldap-check` bereikt FreeIPA via LDAPS, maar stopt op
`grp-forgejo-admin`. Die groep ontbreekt of is voor de anonieme controle niet
zichtbaar. Er zijn binnen deze uitrol geen groepen, accounts of toegangsrechten
gewijzigd. Volledige applicatielogins met gebruikerswachtwoorden zijn niet
getest.

`just internal-pki-check` controleert de CA-bestanden, geldigheid en opname in
alle negen NixOS-configuraties. Beide actieve NixOS-VM-generaties zijn gebouwd
en uitgerold. De overige bestaande wijzigingen in de checkout zijn behouden.
