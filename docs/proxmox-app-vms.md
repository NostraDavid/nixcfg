# Proxmox app VMs

Deze repo definieert drie NixOS guests voor Proxmox:

- `homepage`: dashboard host voor Homepage.
- `apps`: gedeelde host voor het huishoudboekje en de recepten/boodschappen app.
- `forgejo`: eigen Git-dienst op VM 110, `prd-svc-forgejo-01`.

De root disks zijn vervangbaar. Applicatie-state staat op aparte Proxmox disks
die NixOS mount via filesystem labels.

## Waar voer je wat uit?

| Stap                         | Waar                                      | Voorbeeld                                        |
| ---------------------------- | ----------------------------------------- | ------------------------------------------------ |
| Nix-config checken           | laptop/werkstation, in deze repo          | `just app-vms-check`                             |
| VM en extra disks aanmaken   | laptop/werkstation, in deze repo          | `just tofu-proxmox-apply`                        |
| Disks formatteren en labelen | in de betreffende NixOS VM                | `just format-homepage-data /dev/disk/by-id/...`  |
| NixOS-config deployen        | laptop/werkstation, in deze repo          | `just deploy-homepage root@<vm-ip>`              |
| App binaries plaatsen        | in de `apps` VM, of via je app deployment | `/opt/huishoudboekje/current/bin/huishoudboekje` |

De `just` recipes staan in deze repo en voer je dus normaal uit vanaf je laptop
of werkstation. De formatteer-recipes moeten tegen een block device in de VM
wijzen. Gebruik die niet op je laptop tenzij die disk daar echt bewust is
aangekoppeld.

## OpenTofu

OpenTofu beheert de Proxmox VM-shells en disks in `infra/proxmox`. VM 210
(`homepage`) en 211 (`apps`) gebruiken `datastore_id`, standaard `local`. Alleen
VM 110 gebruikt `forgejo_datastore_id`, standaard `vm_storage_1`. De
NixOS-installatie-ISO voor Forgejo blijft op `local`; zijn systeem- en datadisk
staan op `vm_storage_1`.

De lokale OpenTofu-state staat in `infra/proxmox/terraform.tfstate` en blijft
buiten Git. VM 210 en 211 zijn daarin geïmporteerd; VM 110 is via OpenTofu
aangemaakt. Bewaar deze state bij een verhuizing van de checkout. Zonder state
zou een nieuwe `apply` de bestaande VM's opnieuw proberen aan te maken. Een
momentopname na het aanmaken van VM 110 staat in
`~/.local/state/nixcfg/proxmox/terraform.tfstate-after-vm110-20260927`.

De Proxmox API is bereikbaar via `https://192.168.2.100:8006/api2/json/`. De
`bpg/proxmox` provider verwacht in `proxmox_endpoint` de root URL, dus
`https://192.168.2.100:8006/`; de provider voegt het API-pad zelf toe.

Maak eerst een Proxmox API token. Zet de echte token niet in Git. Gebruik een
lokale `terraform.tfvars` of environment variables:

```bash
just tofu-proxmox-tfvars
```

Of:

```bash
export TF_VAR_proxmox_api_token='user@realm!token-id=secret'
export TF_VAR_node_name='POwerMonolith'
```

Voer daarna lokaal uit, vanuit deze repo:

```bash
just tofu-proxmox-init
just tofu-proxmox-check
just tofu-proxmox-plan
just tofu-proxmox-apply
```

Handige beheercommando's:

```bash
just tofu-proxmox-permissions
just tofu-proxmox-output
just tofu-proxmox-state
just tofu-proxmox-plan-destroy
just tofu-proxmox-destroy
```

Als `just tofu-proxmox-apply` faalt met HTTP 403, heeft de API token te weinig
rechten. Controleer wat Proxmox voor de token teruggeeft:

```bash
just tofu-proxmox-permissions
```

Voor deze VM-aanmaak heeft de token rechten nodig op minimaal:

- `/vms`: VM allocatie en configuratie.
- `/nodes/POwerMonolith`: VM beheer op de node.
- `/storage/local`: disks aanmaken op de datastore.
- `/storage/vm_storage_1`: de Forgejo-disks aanmaken op de datastore.

Let op: als de token met privilege separation is aangemaakt, moeten zowel de
user `terraform@pve` als de token `terraform@pve!tf2` voldoende rechten hebben.
De tokenrechten zijn dan een beperking bovenop de userrechten.

Pragmatische start: geef tijdelijk `PVEAdmin` op `/` met propagate aan beide:

- user: `terraform@pve`
- API token: `terraform@pve!tf2`

Test daarna `apply` en maak later een beperktere rol voor VM beheer.

De OpenTofu config maakt de VM's aan maar start ze nog niet automatisch. Dat is
bewust: installeer eerst NixOS of koppel een NixOS image/template aan, zodat de
root disk het label `nixos` krijgt en SSH bereikbaar wordt. Forgejo krijgt de al
aanwezige minimale NixOS-ISO als cdrom. De bootvolgorde probeert eerst de
systeemdisk en daarna de ISO. Zet `on_boot` pas aan nadat de installatie en
Forgejo zijn gecontroleerd. De Forgejo-resource heeft `prevent_destroy`, zodat
een gewone OpenTofu-destroy de datadisk niet wist.

## Proxmox VM layout

De Nix-config gaat ervan uit dat de VM via DHCP netwerk krijgt en dat SSH
bereikbaar is.

`homepage`:

- root disk voor NixOS.
- extra disk voor Homepage state.

`apps`:

- root disk voor NixOS.
- extra disk voor PostgreSQL.
- extra disk voor uploads/applicatie-state.

`forgejo`:

- 32 GiB systeemdisk (`virtio0`) voor NixOS.
- 64 GiB datadisk (`virtio1`, serienummer `forgejo-state`) voor PostgreSQL,
  repositories en Forgejo-geheimen.
- 2 CPU-cores, 4 GiB RAM en netwerk via `vmbr0`.

De root disk moet uiteindelijk een filesystem met label `nixos` hebben. De extra
state disks krijgen de labels hieronder.

## Verwachte disks

`homepage`:

| mountpoint          | label           | purpose               |
| ------------------- | --------------- | --------------------- |
| `/`                 | `nixos`         | OS/root disk          |
| `/var/lib/homepage` | `homepage-data` | Homepage config/state |

`apps`:

| mountpoint            | label           | purpose                     |
| --------------------- | --------------- | --------------------------- |
| `/`                   | `nixos`         | OS/root disk                |
| `/var/lib/postgresql` | `apps-postgres` | PostgreSQL data             |
| `/srv/apps`           | `apps-data`     | uploads en applicatie-state |

`forgejo`:

| mountpoint     | label           | purpose                            |
| -------------- | --------------- | ---------------------------------- |
| `/`            | `nixos`         | OS/root disk                       |
| `/srv/forgejo` | `forgejo-state` | database, repositories en geheimen |

Laat de nieuwe Forgejo-datadisk leeg. De NixOS-module controleert het opgegeven
virtio-apparaat en initialiseert alleen een volledig lege disk met het label
`forgejo-state`. Formatteer deze disk niet met de recipes hieronder.

## State disks formatteren

Voer dit uit in de betreffende VM, nadat de extra disks in Proxmox zijn
aangekoppeld.

Zoek eerst de juiste disk:

```bash
ls -l /dev/disk/by-id/
lsblk -f
```

Gebruik daarna de passende recipe vanuit deze repo:

```bash
just format-homepage-data /dev/disk/by-id/<homepage-data-disk>
just format-apps-postgres /dev/disk/by-id/<apps-postgres-disk>
just format-apps-data /dev/disk/by-id/<apps-data-disk>
```

Gebruik `/dev/disk/by-id/...` bij formatteren. Vertrouw niet op `/dev/sdb`
achtige namen, omdat device-volgorde kan veranderen.

## Config checken

Voer dit uit op je laptop/werkstation in deze repo:

```bash
just app-vms-check
```

Deze recipe gebruikt `path:.`, zodat checks ook werken zolang nieuwe files nog
niet door Git getrackt zijn.

## Deployen

Voer dit uit op je laptop/werkstation in deze repo, zodra SSH naar de VM werkt:

```bash
just deploy-homepage root@<homepage-ip>
just deploy-apps root@<apps-ip>
just deploy-forgejo david@<forgejo-ip>
```

Als DNS werkt, kan dit ook:

```bash
just deploy-homepage root@homepage
just deploy-apps root@apps
just deploy-forgejo
```

De deploy recipes gebruiken bewust `path:.`, zodat ze ook werken tijdens lokaal
itereren met untracked files.

De Forgejo-host gebruikt DHCP. Reserveer zijn adres in de router en laat
`forgejo.home.arpa` daarnaar verwijzen voordat je de dienst gebruikt. De NixOS
config adverteert `http://forgejo.home.arpa:3000/` voor webtoegang en poort 2222
voor Git over SSH. Na de eerste start staat het initiële adminwachtwoord in
`/srv/forgejo/admin-password` op de VM.

## Applicatie entrypoints

De `apps` host verwacht gedeployde applicatie-binaries op:

```text
/opt/huishoudboekje/current/bin/huishoudboekje
/opt/recepten/current/bin/recepten
```

De systemd units gebruiken `ConditionPathIsExecutable`, dus ze worden
overgeslagen zolang de binaries nog niet bestaan.
