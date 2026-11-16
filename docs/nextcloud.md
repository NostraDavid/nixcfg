# Richt Nextcloud in op een eigen VM

Gebruik VM 115, `prd-svc-nextcloud-01`, op `192.168.2.115`. De standaardgrootte
is twee CPU-cores, 4 GiB RAM, 32 GiB systeemdisk en 64 GiB datadisk. Controleer
het IP-adres en de opslagcapaciteit voor de uitrol. VM 114 blijft een
herstelkopie.

FreeIPA verzorgt LDAP via `ldaps://ldap.powerlan.empire:636`. Alleen leden van
`grp-nextcloud-user` mogen aanmelden. De Git-policy verleent aanvankelijk alleen
`nostradavid` toegang. Dit geeft geen Nextcloud-beheerrechten.

## Test eerst lokaal

```bash
just nextcloud-check
```

De test start de echte Nextcloud-module, PostgreSQL en een geïsoleerde
OpenLDAP-server met fictieve accounts. Hij controleert LDAP-aanmelden,
WebDAV-upload en download, verkeerde wachtwoorden, groepsuitsluiting,
certificaatcontrole, herhaald configureren, een herstart en wachtwoordrotatie.
Hij gebruikt geen productieaccounts of bestanden. De OpenBao-test controleert
ook dat afnemers elkaars bindwachtwoord niet kunnen lezen.

## Maak de VM aan

Gebruik de hoofdstack `infra/proxmox` niet: de actuele state ontbreekt daar.
Maak deze VM aan via Proxmox' eigen beheer en beheer het systeem daarna met
NixOS.

1. Controleer dat VM 115 en IP `192.168.2.115` vrij zijn.
2. Bouw het systeemimage met `just nextcloud-image`.
3. Upload `nixos.qcow2` naar **local → Import** in Proxmox. Een gecomprimeerde
   QCOW2-kopie met dezelfde inhoud is ook bruikbaar.
4. Maak op de Proxmox-node uitsluitend VM 115 aan:

   ```bash
   qm create 115 --name prd-svc-nextcloud-01 --cores 2 --cpu host \
     --memory 4096 --ostype l26 --bios seabios --agent enabled=1 \
     --net0 virtio,bridge=vmbr0 --serial0 socket --onboot 1 --protection 1 \
     --virtio0 vm_storage_1:0,import-from=/var/lib/vz/import/nixcfg-nextcloud.qcow2,serial=nextcloud-root \
     --virtio1 vm_storage_1:64,serial=nextcloud-state --boot order=virtio0
   qm start 115
   ```

5. Controleer de SSH-hostsleutel via de Proxmox-console en neem die op in
   `known_hosts`. De gebruiker `david` gebruikt dezelfde publieke sleutels als
   de bestaande NixOS-gasten.

De eerste start initialiseert uitsluitend de volledig lege disk met serienummer
`nextcloud-state`. Een bestaande ext4-disk met het juiste label blijft intact.
Een disk met andere inhoud wordt geweigerd. Stateful services vereisen de mount
`/srv/nextcloud` en schrijven bij een ontbrekende disk geen vervangende database
naar de systeemdisk.

## Koppel de directory en het bindwachtwoord

Voer de bestaande FreeIPA-policy eerst als plan uit en controleer de
wijzigingen:

```bash
just freeipa-policy-plan
just freeipa-policy-apply
just openbao-directory-bootstrap
```

De laatste stap maakt `nextcloud-reader` aan en breidt alleen de bestaande
OpenBao-wachtwoorddelegatie uit. FreeIPA-beheer vereist een eigen interactief
Kerberos-ticket. Gebruik geen persoonlijk beheeraccount als
Nextcloud-bindaccount.

Deploy de bijgewerkte OpenBao-configuratie pas wanneer een huidige
OpenBao-beheerlogin beschikbaar is. De initiële root-token is ingetrokken.
`openbao-ops` accepteert voor latere enrollment een tijdelijke beheer-token via
`BAO_TOKEN`. Houd die buiten Git, de shellgeschiedenis en commandoregels.
Herinitialiseer de bestaande kluis niet.

Voer op de OpenBao-VM met die procesomgeving uit:

```bash
sudo --preserve-env=BAO_TOKEN openbao-ops enroll nextcloud-reader
sudo --preserve-env=BAO_TOKEN openbao-ops activate nextcloud-reader
```

Breng alleen `/srv/openbao/ops/nextcloud-reader-credentials.json` over naar
`/srv/nextcloud/openbao-consumer/credentials.json` op de nieuwe VM. Gebruik mode
`0600` en een directory met mode `0700`. Deze AppRole mag uitsluitend zijn eigen
LDAP-wachtwoord ophalen en de eigen status bevestigen.

Start vervolgens op de Nextcloud-VM:

```bash
sudo systemctl start openbao-consumer.service
sudo -u nextcloud nextcloud-occ ldap:test-config s01
```

OpenBao roteert het bindwachtwoord dagelijks. De afnemer controleert iedere
minuut het huidige wachtwoord. Hij verifieert eerst een LDAPS-bind en daarna de
werkelijke Nextcloud-configuratie voordat hij de status bevestigt. Verwijder de
enrollmentkopie uit `/srv/openbao/ops` na een geslaagde controle.

## Publiceer HTTPS en DNS

1. Kopieer de openbare backend-CA uit
   `/srv/nextcloud/caddy/.local/share/caddy/pki/authorities/local/root.crt` op
   de Nextcloud-VM naar `/srv/proxy/nextcloud-backend-root.crt` op VM 111, met
   mode `0644`. Kopieer geen privésleutel.
2. Deploy de certificaten-VM en daarna de proxy:

   ```bash
   just deploy-certs
   just deploy-proxy
   ```

3. Laat Pi-hole `nextcloud.powerlan.empire` naar `192.168.2.111` verwijzen.
4. Controleer de volledige verbinding:

   ```bash
   curl --fail --cacert certs/forgejo-ca.crt \
     --resolve nextcloud.powerlan.empire:443:192.168.2.111 \
     https://nextcloud.powerlan.empire/status.php
   ```

De proxy controleert de vastgelegde backend-CA. De backendpoort `8443`
accepteert alleen VM 111. PostgreSQL, Redis en de HTTP-applicatie zijn niet
vanaf het LAN bereikbaar. Toegangslogs staan uit zodat bestandsnamen en
URL-tokens daar niet terechtkomen.

## Beheer en herstel

Open `https://nextcloud.powerlan.empire` en meld aan met je normale
FreeIPA-gebruikersnaam en wachtwoord. Het afzonderlijke lokale account
`recovery-admin` blijft beschikbaar als LDAP uitvalt. Het eenmalig gegenereerde
wachtwoord staat op de VM in `/srv/nextcloud/secrets/admin-password` en wordt
niet in buildlogs afgedrukt.

Alle bestanden, accountkoppelingen, PostgreSQL-data, herstelgegevens en
Caddy-state staan op de datadisk. LDAP-gebruikers worden gekoppeld via het
onveranderlijke FreeIPA-veld `ipaUniqueID`. Wijzig dit veld niet achteraf. Het
verwijderen van groepslidmaatschap verwijdert geen bestanden automatisch.

Neem de volledige VM met beide disks op in de bestaande Proxmox-back-up en
controleer een herstel voordat je er unieke bestanden op bewaart. Voor een
applicatiekopie zijn zowel PostgreSQL als de Nextcloud-configuratie en bestanden
nodig. Zet Nextcloud tijdens die kopie in onderhoudsmodus en pauzeer schrijvende
cronjobs. Een kopie van alleen de bestanden is onvoldoende. De datadisk en
back-ups bevatten ook authenticatiemateriaal en vereisen dezelfde
toegangsbeperking.

Gebruik voor latere softwarewijzigingen:

```bash
just deploy-nextcloud
```

Een nieuw image vervangt de bestaande systeemdisk niet automatisch. Gebruik
`deploy-nextcloud` voor updates en behoud de datadisk. Nextcloud ondersteunt
geen sprongen over meerdere hoofdversies bij een upgrade.

## Ontwerpkeuze

De native NixOS-module sluit aan op het bestaande beheer van PHP, PostgreSQL,
Redis en systeemimages. Een officiële container zou ook image-digests,
containerrechten en veranderlijke applicatiecode introduceren. Beide onderzochte
ontwerpen kozen daarom de native module. De werkende browserconsole maakt
VM-aanmaak via `qm` mogelijk, zonder een extra API-toegang en provisioningstate.
De vergelijking gebruikte twee onafhankelijke ontwerpen met hetzelfde
beschikbare model; er was geen beoordelaar uit een andere modelfamilie
beschikbaar.

De configuratie gebruikt de officiële
[LDAP-interface](https://docs.nextcloud.com/server/35/admin_manual/occ_ldap.html).
Het bindwachtwoord gaat via standaardinvoer naar `occ config:import` en komt
niet in procesargumenten of de Nix-store. Nextcloud slaat deze waarde zelf
base64 op; dat is geen versleuteling. Zie de
[Nextcloud-configuratiecode](https://github.com/nextcloud/server/blob/v35.0.2/apps/user_ldap/lib/Configuration.php).

## Uitrolcontrole op 15 november 2026

VM 115 draait met Nextcloud 35.0.2. DNS verwijst naar de bestaande proxy en
`https://nextcloud.powerlan.empire/status.php` geeft via gecontroleerde TLS
HTTP 200. De echte LDAPS-bind, de lookup van `nostradavid`, de OpenBao-status en
een herstart van de productie-VM zijn gecontroleerd. Forgejo, Homepage en
OpenBao geven na de proxy-uitrol eveneens HTTP 200.

De lokale test controleert ook upload, download, geweigerde toegang,
certificaatcontrole en wachtwoordrotatie. Een persoonlijke wachtwoordlogin en
een herstel uit back-up zijn niet uitgevoerd.
