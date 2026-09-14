# Verificatie van het lokale Proxmox-lab

Uitgevoerd op 14 september 2026. De definitieve omgeving draait op wodan. De
gebruikscommando's staan in [de handleiding](proxmox-lab.md).

| Controle                       | Resultaat                        |
| ------------------------------ | -------------------------------- |
| Wodan-hostbuild                | Gelijk aan de werkmap            |
| Forgejo-image                  | Gebouwd                          |
| Homepage en apps               | Evaluatie geslaagd               |
| OpenTofu, lint en formattering | Geslaagd                         |
| Agent-instructiecheck          | Geslaagd                         |
| Controllerchecks               | 11 tests geslaagd                |
| Imagetests met 64-GiB-disk     | 7 scenario's geslaagd            |
| Volledige reset en herbouw     | Zonder tussenkomst geslaagd      |
| Web-login en Git               | Geslaagd                         |
| Backup en geïsoleerd herstel   | Zelfde repositorycommit          |
| Stop en start                  | Daarna geen OpenTofu-wijzigingen |
| Aparte virtuele LAN-client     | Beide servers bereikbaar         |

De imagetests controleren een ontbrekende disk, een disk met een vreemd
filesystem, een disk met ongelabelde bestaande data, eerste installatie,
vervanging van de systeemdisk, herstarten en herstel van een datakopie. De
verkeerde disks bleven byte voor byte behouden. Database, repositories en
Forgejo-geheimen bleven behouden bij vervanging van de systeemdisk.

De controllerchecks dekken ook adresconflicten, productieadressen, ongeldige
backups, behoud van de VM-UUID, een onderbroken reset en een mislukte eerste
start. Een vastgelopen shutdown wordt niet geforceerd.

## Controleerbare gegevens

- Proxmox-manager: 9.2.18, actieve kernel 7.0.14-16-pve.
- Forgejo: 15.0.7; PostgreSQL: 16.15.
- VM 310 is de actieve Forgejo-VM.
- VM 311 bevat de gecontroleerde backup en blijft na labherstart gestopt.
- Git-commit op de oorspronkelijke en herstelde repository:
  `7dda343c550944689fbf52d6222b766809daa0e4`.
- Backup:
  `~/.local/state/proxmox-lab/backups/vzdump-qemu-310-2026_09_14-01_40_53.vma.zst`,
  met een aparte checksum.
- De desktop behield adres 10.0.1.62 op br-lab en de route naar productie.
- Productieconfiguraties en productie-VMs zijn niet gewijzigd.

De LAN-controle gebruikte een zelfstandige VM op de echte bridge, met DHCP-adres
10.0.1.134. Deze testclient is daarna verwijderd. Een controle vanaf de fysieke
productieserver kon niet worden uitgevoerd: de bestaande SSH-sleutel werd daar
niet toegelaten. Er is geen wachtwoord gevraagd en die server is niet aangepast.

## Nog eenmalig blijvend activeren

De hostondersteuning is tijdens de werkzaamheden met `test` geactiveerd. De
definitieve hostconfiguratie is gebouwd, maar nog niet als blijvende
systeemgeneratie ingesteld. Voer daarvoor uit:

```bash
just switch wodan
```

Dit vraagt om de gebruikelijke beheerdersauthenticatie. Die stap is uitgesteld
omdat er vannacht geen nieuw wachtwoord meer mocht worden gevraagd.
