# Interne certificaten vertrouwen

Gebruik de publieke rootcertificaten uit `certs/` voor interne diensten:

- `freeipa.crt` voor `ldap.powerlan.empire`, inclusief LDAPS en StartTLS.
- `forgejo-ca.crt` voor `forgejo.powerlan.empire` via proxy-VM 111.

Download beide certificaten via <http://192.168.2.111/>. Deze pagina werkt
zonder vooraf geïnstalleerde CA. Vergelijk de fingerprints via een
onafhankelijk, vertrouwd kanaal; de HTTP-pagina zelf bewijst niet wie het
certificaat uitgeeft. De proxy serveert alleen de twee publieke CA's, de
controlebestanden en de downloadpagina. Fingerprints op de pagina komen uit
`certs/fingerprints.txt`.

Controleer bestandschecksums met `cd certs && sha256sum -c SHA256SUMS`.
Vergelijk de certificaatfingerprints met `certs/fingerprints.txt` via een
vertrouwd kanaal voordat je de CA's op een nieuw apparaat installeert. De
checksums controleren de overdracht, niet de betrouwbaarheid van de bron.
Verspreid geen privésleutels. Het backend-rootcertificaat van Forgejo blijft
uitsluitend op de proxy vertrouwd.

## Bundels en versies

Download de nieuwste volledige ZIP via
<http://192.168.2.111/powerlan-ca-latest.zip>. Deze bevat beide losse CA's,
`powerlan-ca.pem`, fingerprints, `version.txt` en checksums. De nieuwste
PEM-bundel staat op <http://192.168.2.111/powerlan-ca-latest.pem>. Gebruik PEM
alleen in toepassingen die meerdere CA's per bestand ondersteunen. Installeer op
Debian en Android de losse `.crt`-bestanden uit de ZIP.

De bundel gebruikt stabiele SemVer-versies uit `certs/VERSION`, beginnend bij
`1.0.0`. Verhoog MAJOR bij het verwijderen of vervangen van een vertrouwde CA,
MINOR bij het toevoegen van een CA en PATCH bij metadata- of
verpakkingscorrecties zonder verandering van de vertrouwde CA's.
Websitewijzigingen buiten de bundel vereisen geen nieuwe bundelversie.

Een gepubliceerde versie is onveranderlijk. De uitrol weigert gewijzigde
bundelinhoud onder een bestaande versie; verhoog dan eerst `certs/VERSION`. Nix
controleert het formaat `MAJOR.MINOR.PATCH`. SHA-256 blijft in gebruik voor
checksums en fingerprints. De vaste release-URL is `/releases/1.0.0/`; de ZIP
bevat de volledige SemVer-versie in `version.txt`. De eerdere hash-URL blijft
beschikbaar voor bestaande downloads als archief van vóór de SemVer-overgang.

Oude versies blijven onder `/srv/proxy/certificates/releases/` op de persistente
proxydisk staan en zijn via <http://192.168.2.111/releases/> beschikbaar. Een
release wordt volledig klaargezet voordat ze zichtbaar wordt en wordt bij
opnieuw deployen niet overschreven. Neem deze map mee in de proxydiskback-up.
Gebruik voor nieuwe installaties de nieuwste versie. Controleer de uitrol met
`just internal-pki-bundle-check`.

## NixOS

`modules/internal-pki.nix` voegt beide CA's toe aan de bestaande systeemopslag.
De gedeelde `mkHost`-constructie importeert deze module voor alle NixOS-hosts.
Ook nieuwe hosts die `mkHost` gebruiken krijgen beide CA's.

Voer vanuit deze repository uit:

```bash
just internal-pki-check
just switch wodan
```

Test eerst Wodan. Activeer daarna de overige bereikbare NixOS-hosts met hun
bestaande deployprocedure. Uitgeschakelde machines krijgen de CA's bij hun
volgende activatie. Alleen Home Manager activeren wijzigt geen
systeemvertrouwen. Behoud bij een volledige switch de gebruikelijke controle van
andere openstaande configuratiewijzigingen.

## Debian

Voer deze blokken in dezelfde terminal uit met sudo-rechten. De download en
checksum worden aan dezelfde versie gekoppeld, ook tijdens een nieuwe uitrol.

### Downloaden en controleren

```bash
sudo apt-get update && sudo apt-get install -y ca-certificates curl unzip openssl
workdir=$(mktemp -d) && cd "$workdir" &&
bundle_url=$(curl -fsSL -o powerlan-ca.zip -w '%{url_effective}' http://192.168.2.111/powerlan-ca-latest.zip) &&
curl -fsSL -o powerlan-ca.zip.sha256 "$bundle_url.sha256" &&
sha256sum -c powerlan-ca.zip.sha256 &&
unzip -p powerlan-ca.zip freeipa.crt > freeipa.crt &&
unzip -p powerlan-ca.zip forgejo-ca.crt > forgejo-ca.crt &&
openssl x509 -in freeipa.crt -noout -fingerprint -sha256 &&
openssl x509 -in forgejo-ca.crt -noout -fingerprint -sha256
```

Vergelijk beide fingerprints via een onafhankelijk, vertrouwd apparaat of je
beheerder voordat je installeert. De checksum van dezelfde HTTP-server
controleert de overdracht, niet de identiteit van de CA.

### Installeren en testen

```bash
sudo install -d -m 0755 /usr/local/share/ca-certificates/powerlan &&
sudo install -m 0644 freeipa.crt forgejo-ca.crt /usr/local/share/ca-certificates/powerlan/ &&
sudo update-ca-certificates &&
curl --fail https://forgejo.powerlan.empire/api/healthz
```

De cache- en databasecontrole moeten beide `pass` melden. Dit behoudt de
bestaande vertrouwde CA's. Herstart toepassingen die hun certificaatopslag in
het geheugen bewaren. Houd één PEM-certificaat per `.crt`-bestand, zoals in de
ZIP. Zie de [Debian-documentatie][debian].

### Debian LDAP-client

Als de machine `nslcd` gebruikt, controleer eerst StartTLS met de opdracht uit
het onderdeel Verbindingen controleren. Maak daarna een back-up van
`/etc/nslcd.conf` met behoud van eigenaar en toegangsrechten. Behoud de
bestaande zoekbases en bindinstellingen. Gebruik voor de TLS-instellingen:

```text
uri ldap://ldap.powerlan.empire
ssl start_tls
tls_reqcert demand
tls_cacertfile /etc/ssl/certs/ca-certificates.crt
```

Herstart `nslcd` en test rechtstreeks via de LDAP-NSS-module:

```bash
sudo systemctl restart nslcd
timeout 15 getent -s ldap passwd nostradavid >/dev/null
```

De tweede opdracht moet status 0 geven. Herstel bij een fout de back-up en
herstart `nslcd` opnieuw. Bewaar de back-up uitsluitend op de betreffende host;
het bestand kan een bindwachtwoord bevatten. Zie de [nslcd-documentatie][nslcd].

## Android

Breng beide `.crt`-bestanden over via een vertrouwde verbinding. Vergelijk de
fingerprints. Zoek in Instellingen naar certificaten installeren en kies
CA-certificaat. Installeer beide bestanden. De menunamen verschillen per
toestel.

Test de gebruikte browser en iedere app die een interne dienst benadert. Apps
die op moderne Android-versies mikken vertrouwen gebruikers-CA's niet
automatisch. Gebruik de eigen CA-import als de app die aanbiedt. Noteer anders
de app als niet ondersteund. Root het toestel niet en schakel TLS-controle niet
uit. Zie de [Android-documentatie][android].

## LDAP-containers

De certificaatopslag van de containerhost wordt niet automatisch overgenomen.
Inventariseer actieve en gestopte containers, hun basisimage, persistente
configuratie, LDAP-URL en eventuele eigen certificaatopslag. Lees geen
bindwachtwoorden uit in logs of rapporten. Controleer ook VM's met een
rechtstreeks geïnstalleerde LDAP-client.

Voeg de FreeIPA-CA toe aan de bestaande imagebouw. Voor Debian-, Ubuntu- en
Alpine-images met `ca-certificates` is de bouwstap:

```dockerfile
COPY certs/freeipa.crt /usr/local/share/ca-certificates/powerlan-freeipa.crt
RUN update-ca-certificates
```

Voer deze stap als root uit vóór de bestaande `USER`-instructie. Installeer het
pakket `ca-certificates` via de bestaande pakketinstallatie als het ontbreekt.
Gebruik voor NixOS-containers de gedeelde NixOS-module. Voeg voor Java de CA toe
aan een kopie van de bestaande applicatietruststore en configureer de applicatie
om die te gebruiken. Behoud daarin de bestaande publieke CA's.

Wanneer imagebouw niet beschikbaar is, mount dan het publieke CA-bestand
alleen-lezen en configureer de bestaande LDAP-client om het als trust anchor te
gebruiken. Vervang geen algemene CA-bundel door één intern certificaat. Leg de
mount en LDAP-instellingen vast in de bestaande containerconfiguratie.

Laat certificaat- en hostnaamcontrole ingeschakeld. Bouw of maak de container
opnieuw aan en herhaal de TLS- en applicatiecontrole. Een wijziging met alleen
`docker exec` of `podman exec` verdwijnt bij vervanging en is geen uitrol.

## Verbindingen controleren

Controleer vóór installatie de volledige Forgejo-route:

```bash
curl --fail --cacert certs/forgejo-ca.crt \
  https://forgejo.powerlan.empire/api/healthz
```

Cache en database moeten beide `pass` melden. HTTP 502 na geslaagde TLS-controle
vereist onderzoek van de backend-CA op VM 111.

Controleer na installatie zonder expliciete CA:

```bash
curl --fail https://forgejo.powerlan.empire/api/healthz
git clone https://forgejo.powerlan.empire/nostradavid/forgejo-test.git
openssl s_client -connect ldap.powerlan.empire:636 \
  -servername ldap.powerlan.empire -verify_hostname ldap.powerlan.empire \
  -verify_return_error -CAfile /etc/ssl/certs/ca-certificates.crt </dev/null
```

Voer voor StartTLS de LDAP-controle uit met `-starttls ldap` en poort 389. Test
daarnaast een bestaande applicatie-login zonder wachtwoorden vast te leggen.
Authenticatiefouten na geslaagde TLS-controle zijn een afzonderlijk probleem.
Voer de LDAP-controles ook binnen iedere betrokken container uit.

## CA-vervanging

Maak eerst een back-up van de bestaande CA-state op VM 101 en VM 111. Controleer
een nieuw publiek rootcertificaat via de vertrouwde beheerconsole. Verspreid bij
geplande vervanging eerst de nieuwe CA naast de oude. Vernieuw daarna de
servercertificaten en test alle clients. Verwijder de oude CA pas nadat die
clients zijn overgezet. Bij een gecompromitteerde CA trek je het oude vertrouwen
direct in en herstel je de getroffen clients afzonderlijk.

Werk `SHA256SUMS` en `fingerprints.txt` bij na gecontroleerde vervanging. Caddy
vernieuwt servercertificaten zelf; vervang de vertrouwde root niet bij iedere
servercertificaatvernieuwing. Neem de persistente CA-state op in back-ups.

[debian]: https://manpages.debian.org/bookworm/ca-certificates/update-ca-certificates.8.en.html
[android]: https://developer.android.com/privacy-and-security/security-config
[nslcd]: https://manpages.debian.org/bookworm/nslcd/nslcd.conf.5.en.html
