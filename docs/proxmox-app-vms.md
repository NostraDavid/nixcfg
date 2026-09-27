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
| Forgejo-image en VM maken    | laptop/werkstation, in deze repo          | `just tofu-proxmox-apply`                        |
| Disks formatteren en labelen | in de betreffende NixOS VM                | `just format-homepage-data /dev/disk/by-id/...`  |
| NixOS-config deployen        | laptop/werkstation, in deze repo          | `just deploy-homepage root@<vm-ip>`              |
| App binaries plaatsen        | in de `apps` VM, of via je app deployment | `/opt/huishoudboekje/current/bin/huishoudboekje` |

De `just` recipes staan in deze repo en voer je dus normaal uit vanaf je laptop
of werkstation. De formatteer-recipes moeten tegen een block device in de VM
wijzen. Gebruik die niet op je laptop tenzij die disk daar echt bewust is
aangekoppeld.

## OpenTofu

OpenTofu beheert de Proxmox VM's en disks in `infra/proxmox`. VM 210
(`homepage`) en 211 (`apps`) gebruiken `datastore_id`, standaard `local`. Alleen
VM 110 gebruikt `forgejo_datastore_id`, standaard `vm_storage_1`. De
`tofu-proxmox-plan`- en `tofu-proxmox-apply`-recipes bouwen eerst een
NixOS-image met Forgejo. OpenTofu uploadt die als importbestand naar `local` en
importeert hem als systeemdisk op `vm_storage_1`. De datadisk staat daar ook. Op
Proxmox moet `local` daarvoor het contenttype `Import` toelaten.

De lokale OpenTofu-state staat in `infra/proxmox/terraform.tfstate` en blijft
buiten Git. VM 210 en 211 zijn daarin geïmporteerd; VM 110 is via OpenTofu
aangemaakt. Bewaar deze state bij een verhuizing van de checkout. Zonder state
zou een nieuwe `apply` de bestaande VM's opnieuw proberen aan te maken. Een
momentopname na het installeren van Forgejo staat in
`~/.local/state/nixcfg/proxmox/terraform.tfstate-after-forgejo-image-20260927`.

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
- `/storage/local`: de NixOS-image als importbestand uploaden.
- `/storage/vm_storage_1`: de Forgejo-disks aanmaken op de datastore.

Let op: als de token met privilege separation is aangemaakt, moeten zowel de
user `terraform@pve` als de token `terraform@pve!tf2` voldoende rechten hebben.
De tokenrechten zijn dan een beperking bovenop de userrechten.

Pragmatische start: geef tijdelijk `PVEAdmin` op `/` met propagate aan beide:

- user: `terraform@pve`
- API token: `terraform@pve!tf2`

Test daarna `apply` en maak later een beperktere rol voor VM beheer.

VM 110 start na de eerste `apply` automatisch vanaf de vooraf gebouwde
NixOS-systeemdisk. De Forgejo-module initialiseert alleen een volledig lege
datadisk en start daarna PostgreSQL en Forgejo. Voor VM 210 en 211 blijft de
NixOS-installatie een aparte stap. De Forgejo-resource heeft `prevent_destroy`,
zodat een gewone OpenTofu-destroy de datadisk niet wist.

De image wordt alleen bij het aanmaken van VM 110 naar de systeemdisk
geïmporteerd. Gebruik `just deploy-forgejo` voor latere NixOS-wijzigingen op de
bestaande VM. Een volgende OpenTofu-apply vernieuwt het opgeslagen
importbestand, maar overschrijft de draaiende systeemdisk niet.

## Proxmox VM layout

`homepage` en `apps` krijgen hun netwerkconfiguratie via DHCP. `forgejo`
gebruikt het vaste adres `192.168.2.110/24` op `ens18`, met gateway
`192.168.2.1` en DNS `192.168.2.102`. SSH moet bereikbaar zijn om later te
deployen.

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
just deploy-forgejo
```

Als DNS werkt, kan dit ook:

```bash
just deploy-homepage root@homepage
just deploy-apps root@apps
```

`just deploy-forgejo` gebruikt standaard `david@192.168.2.110` en heeft dus geen
DNS-record nodig.

De deploy recipes gebruiken bewust `path:.`, zodat ze ook werken tijdens lokaal
itereren met untracked files.

Reserveer `192.168.2.110` voor deze VM in de DHCP-server of sluit dat adres uit
van de DHCP-pool, zodat een ander apparaat het niet krijgt. Laat
`forgejo.home.arpa` naar `192.168.2.110` verwijzen. Caddy biedt
`https://forgejo.home.arpa/` op poort 443 aan en stuurt HTTP op poort 80 door
naar HTTPS. Forgejo zelf luistert alleen op `127.0.0.1:3000`. Git over SSH
gebruikt poort 2222. Na de eerste start staat het initiële adminwachtwoord in
`/srv/forgejo/admin-password` op de VM.

Caddy gebruikt een eigen interne CA voor `forgejo.home.arpa`. De CA en de
sleutels staan op de persistente datadisk onder `/srv/forgejo/caddy`; neem die
mee in de backup. Haal het publieke rootcertificaat op en vertrouw het op elk
apparaat dat Forgejo gebruikt:

```bash
ssh david@192.168.2.110 'sudo cat /srv/forgejo/caddy/.local/share/caddy/pki/authorities/local/root.crt' > forgejo-ca.crt
```

Controleer vóór de DNS-wijziging het volledige HTTPS-pad met:

```bash
curl --fail --cacert forgejo-ca.crt \
  --resolve forgejo.home.arpa:443:192.168.2.110 \
  https://forgejo.home.arpa/api/healthz
```

De checks voor cache en database moeten allebei `pass` melden. Importeer
`forgejo-ca.crt` in de vertrouwde CA's van de client of browser voordat je
Forgejo via de browser gebruikt. De private CA-sleutel blijft op de VM.

## Applicatie entrypoints

De `apps` host verwacht gedeployde applicatie-binaries op:

```text
/opt/huishoudboekje/current/bin/huishoudboekje
/opt/recepten/current/bin/recepten
```

De systemd units gebruiken `ConditionPathIsExecutable`, dus ze worden
overgeslagen zolang de binaries nog niet bestaan.
