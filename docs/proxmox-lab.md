# Gebruik het lokale Proxmox-lab

Voer de opdrachten uit in de nixcfg-checkout op wodan. Het lab draait binnen
NixOS en start alleen op verzoek.

## Eerste start

Activeer eerst de hostondersteuning:

```bash
just switch wodan
```

Start daarna het lab:

```bash
just lab-up
```

De eerste start downloadt de gecontroleerde Proxmox-ISO, maakt de virtuele disks
aan en installeert Proxmox automatisch. Daarna bouwt Nix de Forgejo-image en
maakt OpenTofu de Forgejo-VM aan. Dit duurt langer dan een gewone start.

De netwerkbridge behoudt de DHCP-identiteit van de bekabelde aansluiting. De
eerste omzetting gebruikt een NetworkManager-checkpoint. Als het desktopadres of
de verbinding met productie verloren gaat, draait de controller de
netwerkovergang terug.

Open de webinterfaces:

- [Proxmox lab](https://10.0.1.240:8006/), gebruiker `root@pam`.
- [Forgejo lab](http://10.0.1.241:3000/), gebruiker `david`.

Het Proxmox-certificaat komt van de eigen lab-CA. OpenTofu gebruikt de CA uit de
aangemaakte Proxmox-installatie. De browser vraagt aanvankelijk om bevestiging
of het importeren van die CA.

Het Proxmox-wachtwoord staat lokaal in
`~/.local/state/proxmox-lab/pve-password`. Toon het initiële Forgejo-wachtwoord
alleen wanneer je het nodig hebt:

```bash
just forgejo-password
```

Wachtwoorden, tokens en OpenTofu-state staan buiten Git. De datadisk bewaart ook
de Forgejo-geheimen. Een herstart verandert die niet.

## Dagelijks gebruik

Start het bestaande lab met `just lab-up`. Herhaald uitvoeren bewaart de
installatie. Bekijk de toestand met `just lab-status`.

Stop Proxmox en zijn gasten netjes:

```bash
just lab-down
```

Bij een vastgelopen afsluiting meldt de controller een fout. Hij forceert geen
uitschakeling. Bekijk dan de gastconsole en het seriële log dat `lab-status`
aanwijst.

Wijzig de Forgejo-configuratie in Nix en pas die toe:

```bash
just forgejo-deploy
```

Bouw een systeemimage voor een latere installatie met `just forgejo-image`. Dit
image bevat geen repositories, database of private sleutels. OpenTofu gebruikt
een systeemimage alleen voor de eerste VM-aanmaak. Gewone configuratie-updates
lopen via NixOS.

Controleer inloggen en Git:

```bash
just forgejo-smoke
```

Deze controle maakt de private repository `david/nixcfg-lab-smoke` aan. Hij
registreert je publieke SSH-sleutel, pusht een testcommit en controleert de
inhoud via een nieuwe clone.

## Een backup herstellen

Maak een consistente backup:

```bash
just forgejo-backup
```

Proxmox stopt de gast tijdens de backup. De controller kopieert het VMA-archief
en een checksum naar `~/.local/state/proxmox-lab/backups`. Het archief bevat de
systeemdisk en de datadisk, inclusief database en geheimen.

Herstel een gekozen bestand:

```bash
just forgejo-restore /absoluut/pad/naar/vzdump-qemu-310-....vma.zst
```

Deze opdracht maakt VM 311, `forgejo-restore`, op het geïsoleerde netwerk
`vmbr1`. De actieve VM 310 blijft behouden. Een bestaande VM 311 wordt nooit
overschreven. Bekijk de herstel-VM via de Proxmox-console.

Verwijder de herstel-VM pas nadat je de herstelcontrole hebt afgerond.

## Een volledig nieuw lab maken

Archiveer de oude omgeving en bouw een nieuwe:

```bash
just lab-reset
```

De controller sluit het lab af en archiveert de disks onder
`/var/lib/proxmox-lab/archive/<tijdstip>`. Credentials en beheerstate gaan naar
`~/.local/state/proxmox-lab-archive-<tijdstip>`. De gecontroleerde ISO-cache
blijft beschikbaar. Oude archieven worden niet automatisch verwijderd.

De actuele disks staan onder `/var/lib/proxmox-lab/current`. Wis die map niet om
een reset te simuleren: de controller gebruikt ook bijbehorende beheerstate.

## Instellingen aanpassen

Pas de centrale instellingen aan in `infra/proxmox-lab/settings.nix`. Gebruik
`just lab-plan` om de effectieve instellingen te bekijken.

De adressen `10.0.1.240` en `10.0.1.241` zijn voorlopige statische adressen. De
controller controleert op zichtbare adresconflicten. Een uitgeschakeld apparaat
en een toekomstige DHCP-toewijzing zijn daarmee niet uitgesloten. Reserveer de
adressen in de router zodra je die configuratie beheert.

Gewijzigde labinstellingen worden niet stilzwijgend op bestaande disks
toegepast. Gebruik een bewuste reset voor een nieuwe omgeving. De labstack heeft
eigen OpenTofu-state en gebruikt uitsluitend `pve-lab`. De bestaande
productiestack in `infra/proxmox` wordt door deze opdrachten niet aangeroepen.

## Naar productie voorbereiden

Hergebruik `modules/forgejo.nix` in een aparte productiehost. Geef die host
eigen netwerk-, URL-, opslag- en toegangsinstellingen. Controleer vooraf de
Proxmox-versie, beschikbare CPU-opties en opslag.

Gebruik een geteste Nix-revisie om het productiesysteem te bouwen. Migreer
vervolgens de repositories, database en Forgejo-geheimen met een consistente
backup. Maak vóór een applicatie- of databaseschema-upgrade een backup. Een
NixOS-rollback draait een gewijzigde database niet terug.

De andere bestaande productie-VMs vallen buiten dit lab.

## De implementatie controleren

Voer de controllerchecks uit met `just lab-controller-check`. Deze checks
wijzigen het lab niet.

Voer de volledige imagecontrole uit met `just forgejo-image-check`. Die opdracht
boot tijdelijke VMs en controleert ontbrekende en verkeerde disks, inloggen,
Git, herstarten, vervanging van de systeemdisk en herstel van data. De
tijdelijke web- en SSH-poorten luisteren uitsluitend op localhost.

De uitgevoerde controles en de actuele status staan in
[het verificatieverslag](proxmox-lab-verificatie.md).
