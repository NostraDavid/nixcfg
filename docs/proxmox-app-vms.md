# Proxmox app VMs

Deze repo definieert vier NixOS guests voor Proxmox:

- `homepage`: dashboard host voor Homepage.
- `apps`: gedeelde host voor het huishoudboekje en de recepten/boodschappen app.
- `forgejo`: eigen Git-dienst op VM 110, `prd-svc-forgejo-01`.
- `proxy`: gedeelde HTTPS-ingang op VM 111, `prd-svc-proxy-01`.

De root disks zijn vervangbaar. Applicatie-state staat op aparte Proxmox disks
die NixOS mount via filesystem labels.

## Waar voer je wat uit?

| Stap               | Locatie     | Voorbeeld                   |
| ------------------ | ----------- | --------------------------- |
| Nix-config checken | Werkstation | `just app-vms-check`        |
| VM's maken         | Werkstation | `just tofu-proxmox-apply`   |
| Disks formatteren  | Gast-VM     | `just format-homepage-data` |
| NixOS deployen     | Werkstation | `just deploy-proxy`         |

De `just` recipes staan in deze repo en voer je dus normaal uit vanaf je laptop
of werkstation. De formatteer-recipes moeten tegen een block device in de VM
wijzen. Gebruik die niet op je laptop tenzij die disk daar echt bewust is
aangekoppeld.

## OpenTofu

OpenTofu beheert de Proxmox VM's en disks in `infra/proxmox`. VM 210
(`homepage`) en 211 (`apps`) gebruiken `datastore_id`, standaard `local`. VM 110
gebruikt `forgejo_datastore_id` en VM 111 `proxy_datastore_id`, beide standaard
`vm_storage_1`. De `tofu-proxmox-plan`- en `tofu-proxmox-apply`-recipes bouwen
images voor beide VM's. OpenTofu uploadt die als importbestanden naar `local` en
importeert ze als systeemdisks op `vm_storage_1`. De datadisks staan daar ook.
Op Proxmox moet `local` daarvoor het contenttype `Import` toelaten.

De lokale OpenTofu-state staat in `infra/proxmox/terraform.tfstate` en blijft
buiten Git. VM 210 en 211 zijn daarin geïmporteerd; VM 110 en 111 zijn via
OpenTofu aangemaakt. Bewaar deze state bij een verhuizing van de checkout.
Zonder state zou een nieuwe `apply` de bestaande VM's opnieuw proberen aan te
maken. Een momentopname na het installeren van Forgejo staat in
`~/.local/state/nixcfg/proxmox/terraform.tfstate-after-forgejo-image-20260927`.
Een momentopname na het aanmaken van VM 111 staat in
`~/.local/state/nixcfg/proxmox/terraform.tfstate-after-proxy111-20260927`. De
state na het bijwerken van beide import-images staat in
`~/.local/state/nixcfg/proxmox/terraform.tfstate-after-proxy-images-20260927`.

De Proxmox API is bereikbaar via `https://192.168.2.100:8006/api2/json/`. De
`bpg/proxmox` provider verwacht in `proxmox_endpoint` de root URL, dus
`https://192.168.2.100:8006/`; de provider voegt het API-pad zelf toe. De plan-
en apply-recipes gebruiken het vastgelegde certificaat in
`hosts/wodan/certs/proxmox.crt` om de TLS-verbinding te controleren.

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
- `/storage/vm_storage_1`: de Forgejo- en proxydisks aanmaken op de datastore.

Let op: als de token met privilege separation is aangemaakt, moeten zowel de
user `terraform@pve` als de gebruikte `terraform@pve!<token-id>` voldoende
rechten hebben. De tokenrechten zijn dan een beperking bovenop de userrechten.

Pragmatische start: geef tijdelijk `PVEAdmin` op `/` met propagate aan beide:

- user: `terraform@pve`
- API token: `terraform@pve!<token-id>`

Test daarna `apply` en maak later een beperktere rol voor VM beheer.

VM 110 en 111 starten na de eerste `apply` automatisch vanaf hun vooraf gebouwde
NixOS-systeemdisk. Hun modules initialiseren alleen hun aangewezen volledig lege
datadisk. Voor VM 210 en 211 blijft de NixOS-installatie een aparte stap. De
Forgejo- en proxyresources hebben `prevent_destroy`, zodat een gewone
OpenTofu-destroy hun datadisks niet wist.

De images worden alleen bij het aanmaken van VM 110 en 111 naar de systeemdisk
geïmporteerd. Gebruik `just deploy-forgejo` en `just deploy-proxy` voor latere
NixOS-wijzigingen. Een volgende OpenTofu-apply vernieuwt de opgeslagen
importbestanden, maar overschrijft de draaiende systeemdisks niet.

## Proxmox VM layout

`homepage` en `apps` krijgen hun netwerkconfiguratie via DHCP. `forgejo` en
`proxy` gebruiken de vaste adressen `192.168.2.110/24` en `192.168.2.111/24` op
`ens18`, met gateway `192.168.2.1` en DNS `192.168.2.102`. SSH moet bereikbaar
zijn om later te deployen.

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

`proxy`:

- 16 GiB systeemdisk (`virtio0`) voor NixOS.
- 8 GiB datadisk (`virtio1`, serienummer `proxy-state`) voor Caddy's CA en
  certificaten.
- 1 CPU-core, 1 GiB RAM en netwerk via `vmbr0`.

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

`proxy`:

| mountpoint   | label         | purpose                    |
| ------------ | ------------- | -------------------------- |
| `/`          | `nixos`       | OS/root disk               |
| `/srv/proxy` | `proxy-state` | Caddy's CA en certificaten |

Laat de nieuwe Forgejo-datadisk leeg. De NixOS-module controleert het opgegeven
virtio-apparaat en initialiseert alleen een volledig lege disk met het label
`forgejo-state`. Formatteer deze disk niet met de recipes hieronder. Voor de
proxy geldt hetzelfde met het label `proxy-state`.

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
just deploy-proxy
```

Als DNS werkt, kan dit ook:

```bash
just deploy-homepage root@homepage
just deploy-apps root@apps
```

`just deploy-forgejo` en `just deploy-proxy` gebruiken standaard de adressen
`david@192.168.2.110` en `david@192.168.2.111`. Ze hebben dus geen DNS-record
nodig.

De deploy recipes gebruiken bewust `path:.`, zodat ze ook werken tijdens lokaal
itereren met untracked files.

De Pi-hole DHCP-pool geeft adressen van `192.168.2.200` tot en met
`192.168.2.254` uit. Houd de vaste adressen `.110` en `.111` buiten die pool.
Laat `forgejo.powerlan.empire` en `forgejo.home.arpa` naar `192.168.2.111`
verwijzen. De proxy op VM 111 bedient de canonieke URL
`https://forgejo.powerlan.empire/` en leidt de oude naam `forgejo.home.arpa`
daarnaartoe. Hij stuurt Git over SSH op poort 2222 door naar VM 110. De
HTTPS-verbinding tussen beide VM's gebruikt de backend-Caddy op VM 110 op
poort 8443. De firewall laat die poort alleen vanaf VM 111 toe. Backend-Caddy
vertrouwt doorgestuurde clientadressen alleen van VM 111. Forgejo zelf luistert
alleen op `127.0.0.1:3000`. Na de eerste start staat het initiële
adminwachtwoord in `/srv/forgejo/admin-password` op VM 110.

VM 111 is de gedeelde ingang voor andere diensten. Voeg daarvoor een extra
Caddy-vhost toe in `modules/hosts/proxy.nix` en wijs de bijbehorende DNS-naam
naar `.111`. Elke backend kan zijn eigen HTTPS-certificaat en toegangsregels
hebben.

Caddy gebruikt twee interne CA's. De publieke CA en sleutels staan op de
persistente proxydisk onder `/srv/proxy/caddy`. De backend-CA staat op de
Forgejo-disk onder `/srv/forgejo/caddy`; VM 111 vertrouwt het publieke
backend-rootcertificaat in `/srv/proxy/backend-root.crt`. Neem beide datadisks
mee in de backup. Bij de verhuizing is de bestaande publieke CA van VM 110 naar
VM 111 overgezet, zodat Chromium hetzelfde rootcertificaat blijft vertrouwen. De
oude publieke CA-sleutels zijn van VM 110 verwijderd.

Na een herstel met een lege proxydisk moet het publieke backend-rootcertificaat
opnieuw naar VM 111. Kopieer alleen het certificaat:

```bash
ssh david@192.168.2.110 sudo cat \
  /srv/forgejo/caddy/.local/share/caddy/pki/authorities/backend/root.crt \
  > forgejo-backend-ca.crt
scp forgejo-backend-ca.crt david@192.168.2.111:/tmp/
ssh david@192.168.2.111 sudo install -m 0644 -o caddy -g caddy \
  /tmp/forgejo-backend-ca.crt /srv/proxy/backend-root.crt
just deploy-proxy
```

Haal het publieke rootcertificaat op en vertrouw het op elk apparaat dat Forgejo
gebruikt:

```bash
ssh david@192.168.2.111 \
  sudo cat /srv/proxy/caddy/.local/share/caddy/pki/authorities/local/root.crt \
  > forgejo-ca.crt
```

Controleer vóór de DNS-wijziging het volledige HTTPS-pad met:

```bash
curl --fail --cacert forgejo-ca.crt \
  --resolve forgejo.powerlan.empire:443:192.168.2.111 \
  https://forgejo.powerlan.empire/api/healthz
```

De checks voor cache en database moeten allebei `pass` melden. Importeer
`forgejo-ca.crt` in de vertrouwde CA's van de client of browser voordat je
Forgejo via de browser gebruikt. De publieke CA-sleutel blijft op VM 111.

## Forgejo en FreeIPA

FreeIPA draait op `ldap.powerlan.empire` (`192.168.2.101`). De niet-POSIX-groep
`grp-forgejo-user` bepaalt wie via LDAP in Forgejo mag inloggen. Aanvankelijk is
alleen `nostradavid` lid. De Forgejo-VM vertrouwt de FreeIPA-CA uit
`hosts/wodan/certs/freeipa.crt`, zodat LDAPS op poort 636 wordt gecontroleerd.

Controleer de verbinding en maak daarna een beperkt LDAP-systeemaccount plus
Forgejo-aanmeldbron aan vanaf het werkstation:

```bash
just forgejo-ldap-check
just forgejo-ldap-bootstrap
```

De bootstrap vraagt interactief om het FreeIPA Directory Manager-wachtwoord.
Voer dat zelf in; zet het niet in Git of de chat. Het commando maakt
`uid=forgejo-reader,cn=sysaccounts,cn=etc,dc=powerlan,dc=empire` aan en bewaart
het bindwachtwoord alleen op VM 110 in `/srv/forgejo/ldap-bind-password`
(eigenaar `forgejo`, mode `0600`). Opnieuw uitvoeren gebruikt hetzelfde
wachtwoord en werkt de bestaande aanmeldbron bij.

De aanmeldbron zoekt onder `cn=users,cn=accounts,dc=powerlan,dc=empire` en laat
alleen leden van `grp-forgejo-user` toe. LDAP-accounts krijgen niet automatisch
Forgejo-beheerdersrechten. Het lokale adminaccount blijft beschikbaar. Forgejo
synchroniseert LDAP-gebruikers ieder uur; als de groep leeg wordt, mag de
synchronisatie ook alle gebruikers van deze bron deactiveren. Controleer na het
toevoegen of verwijderen van een groepslid de toegang opnieuw, ook via Git over
SSH.

## Applicatie entrypoints

De `apps` host verwacht gedeployde applicatie-binaries op:

```text
/opt/huishoudboekje/current/bin/huishoudboekje
/opt/recepten/current/bin/recepten
```

De systemd units gebruiken `ConditionPathIsExecutable`, dus ze worden
overgeslagen zolang de binaries nog niet bestaan.
