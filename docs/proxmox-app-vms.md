# Proxmox app VMs

Deze repo definieert twee NixOS guests voor Proxmox:

- `homepage`: dashboard host voor Homepage.
- `apps`: gedeelde host voor het huishoudboekje en de recepten/boodschappen app.

De root disks zijn vervangbaar. Applicatie-state staat op aparte Proxmox disks
die NixOS mount via filesystem labels.

## Waar voer je wat uit?

| Stap                         | Waar                                           | Voorbeeld                                        |
| ---------------------------- | ---------------------------------------------- | ------------------------------------------------ |
| Nix-config checken           | laptop/werkstation, in deze repo               | `just app-vms-check`                             |
| VM en extra disks aanmaken   | laptop/werkstation, in deze repo               | `just tofu-proxmox-apply`                        |
| Disks formatteren en labelen | in de betreffende NixOS VM                     | `just format-homepage-data /dev/disk/by-id/...`  |
| NixOS-config deployen        | laptop/werkstation, in deze repo               | `just deploy-homepage root@<vm-ip>`              |
| App binaries plaatsen        | in de `apps` VM, of via je app deployment      | `/opt/huishoudboekje/current/bin/huishoudboekje` |

De `just` recipes staan in deze repo en voer je dus normaal uit vanaf je laptop
of werkstation. De formatteer-recipes moeten tegen een block device in de VM
wijzen. Gebruik die niet op je laptop tenzij die disk daar echt bewust is
aangekoppeld.

## OpenTofu

OpenTofu beheert de Proxmox VM-shells en disks in `infra/proxmox`.

De Proxmox API is bereikbaar via
`https://192.168.2.100:8006/api2/json/`. De `bpg/proxmox` provider verwacht
in `proxmox_endpoint` de root URL, dus `https://192.168.2.100:8006/`; de
provider voegt het API-pad zelf toe.

Maak eerst een Proxmox API token. Zet de echte token niet in Git. Gebruik een
lokale `terraform.tfvars` of environment variables:

```bash
just tofu-proxmox-tfvars
```

Of:

```bash
export TF_VAR_proxmox_api_token='user@realm!token-id=secret'
export TF_VAR_node_name='pve'
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
just tofu-proxmox-output
just tofu-proxmox-state
just tofu-proxmox-plan-destroy
just tofu-proxmox-destroy
```

De OpenTofu config maakt de VMs aan maar start ze nog niet automatisch. Dat is
bewust: installeer eerst NixOS of koppel een NixOS image/template aan, zodat de
root disk het label `nixos` krijgt en SSH bereikbaar wordt.

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

De root disk moet uiteindelijk een filesystem met label `nixos` hebben. De
extra state disks krijgen de labels hieronder.

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
```

Als DNS werkt, kan dit ook:

```bash
just deploy-homepage root@homepage
just deploy-apps root@apps
```

De deploy recipes gebruiken bewust `path:.`, zodat ze ook werken tijdens lokaal
itereren met untracked files.

## Applicatie entrypoints

De `apps` host verwacht gedeployde applicatie-binaries op:

```text
/opt/huishoudboekje/current/bin/huishoudboekje
/opt/recepten/current/bin/recepten
```

De systemd units gebruiken `ConditionPathIsExecutable`, dus ze worden
overgeslagen zolang de binaries nog niet bestaan.
