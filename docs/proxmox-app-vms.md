# Proxmox app VMs

Deze repo definieert zes NixOS guests voor Proxmox:

- `homepage`: dashboard op VM 103, `prd-svc-homepage-01`; zie
  [Homepage](homepage.md).
- `apps`: gedeelde host voor het huishoudboekje en de recepten/boodschappen app.
- `forgejo`: eigen Git-dienst op VM 110, `prd-svc-forgejo-01`.
- `proxy`: HTTPS-ingang en SSH-doorsturing op VM 111, `prd-svc-proxy-01`.
- `certs`: CA, certificaatuitgifte, downloads en bewaking op VM 113,
  `prd-svc-certs-01`.
- `openbao`: servicegeheimen op VM 112, `prd-svc-secrets-01`. Zie
  [OpenBao inrichten en herstellen](openbao.md).

De root disks zijn vervangbaar. Applicatie-state staat op aparte Proxmox disks
die NixOS mount via filesystem labels.

## Waar voer je wat uit?

| Stap               | Locatie     | Voorbeeld                 |
| ------------------ | ----------- | ------------------------- |
| Nix-config checken | Werkstation | `just app-vms-check`      |
| VM's maken         | Werkstation | `just tofu-proxmox-apply` |
| Disks formatteren  | Gast-VM     | `just format-apps-data`   |
| NixOS deployen     | Werkstation | `just deploy-proxy`       |

De `just` recipes staan in deze repo en voer je dus normaal uit vanaf je laptop
of werkstation. De formatteer-recipes moeten tegen een block device in de VM
wijzen. Gebruik die niet op je laptop tenzij die disk daar echt bewust is
aangekoppeld.

## OpenTofu

De configuratie in `infra/proxmox` definieert Homepage op VM 103 en `apps` op VM
211 met opslag `datastore_id`, standaard `local`. Forgejo 110, proxy 111 en
certificaten 113 gebruiken standaard `vm_storage_1`. De plan- en apply-recipes
bouwen vier NixOS-images en bieden die via het contenttype `Import` op `local`
aan. OpenBao 112 heeft zijn eigen stapel `infra/openbao`.

De huidige checkout bevat geen state voor de hoofdstack. De uitbreiding met VM
113 en de verhuizingen van 210 naar 114 en daarna naar 103 zijn via Proxmox
uitgevoerd. Gebruik geen lege hoofdstack voor `apply`. Herstel eerst de
bijbehorende state of importeer de bestaande resources, inclusief
`proxmox_virtual_environment_vm.app["homepage"]` met ID 103 en
`proxmox_virtual_environment_vm.certs` met ID 113. Controleer daarna een plan
zonder vervanging of verwijdering van bestaande disks. Bestaande historische
statekopieën onder `~/.local/state/nixcfg/proxmox/` beschrijven de oude
indeling.

De webinterface staat op [proxmox.powerlan.empire](proxmox-web.md). De directe
Proxmox API blijft bereikbaar via `https://192.168.2.100:8006/api2/json/`. De
`bpg/proxmox` provider verwacht in `proxmox_endpoint` de root URL, dus
`https://192.168.2.100:8006/`; de provider voegt het API-pad zelf toe. De plan-
en apply-recipes gebruiken het vastgelegde certificaat in
`hosts/physical/wodan/certs/proxmox.crt` om de TLS-verbinding te controleren.

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
datadisk. VM 103 en 113 gebruiken eveneens een vooraf gebouwd NixOS-image.
Alleen VM 211 houdt een aparte installatiestap. De Forgejo- en proxyresources
hebben `prevent_destroy`, zodat een gewone OpenTofu-destroy hun datadisks niet
wist.

De images worden alleen bij het aanmaken van de vier image-VM's naar de
systeemdisk geïmporteerd. Gebruik `just deploy-forgejo`, `just deploy-proxy`,
`just deploy-certs` en `just deploy-homepage` voor latere NixOS-wijzigingen. Een
volgende OpenTofu-apply vernieuwt de opgeslagen importbestanden, maar
overschrijft de draaiende systeemdisks niet.

## Proxmox VM layout

Homepage draait op VM 103 onder `https://home.powerlan.empire/`, met de naam
`prd-svc-homepage-01`. De proxy op VM 111 verzorgt HTTPS. De certificaten-VM 113
biedt `https://certs.powerlan.empire/` rechtstreeks aan. Zie
[de scheiding en herstelgegevens](service-vm-split.md). VM 210 is na een
geverifieerde kopie van beide disks verwijderd. De oude disks van VM 103 blijven
losgekoppeld bewaard. VM 114 blijft uitgeschakeld als herstelkopie.

Alleen `apps` gebruikt DHCP. Forgejo, proxy, certificaten en Homepage gebruiken
respectievelijk `192.168.2.110/24`, `.111/24`, `.113/24` en `.103/24` op
`ens18`, met gateway `192.168.2.1` en DNS `192.168.2.102`.

`homepage`:

- 16 GiB rootdisk voor NixOS.
- 8 GiB oorspronkelijke sparedisk, behouden zonder formatteren of mount.
- 1 CPU-core en 1 GiB RAM.

`certs`:

- 16 GiB systeemdisk en 8 GiB persistente disk met label `certs-state`.
- Mount `/srv/certs` voor de vertrouwde CA, uitgifte en openbare releases.
- 1 CPU-core en 1 GiB RAM.

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
- 8 GiB datadisk (`virtio1`, serienummer `proxy-state`) voor Caddy's eigen
  serversleutels en ACME-state.
- 1 CPU-core, 1 GiB RAM en netwerk via `vmbr0`.

De root disk moet uiteindelijk een filesystem met label `nixos` hebben. De extra
state disks krijgen de labels hieronder.

## Verwachte disks

`homepage`:

| mountpoint | label   | purpose      |
| ---------- | ------- | ------------ |
| `/`        | `nixos` | OS/root disk |

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

| mountpoint   | label         | purpose                      |
| ------------ | ------------- | ---------------------------- |
| `/`          | `nixos`       | OS/root disk                 |
| `/srv/proxy` | `proxy-state` | serversleutels en ACME-state |

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
just deploy-homepage
just deploy-apps root@<apps-ip>
just deploy-forgejo
just deploy-proxy
```

Als DNS werkt, kan dit ook:

```bash
just deploy-homepage
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
Caddy-vhost toe in `hosts/virtual/proxy/default.nix` en wijs de bijbehorende
DNS-naam naar `.111`. Elke backend kan zijn eigen HTTPS-certificaat en
toegangsregels hebben.

De publieke CA en haar sleutels staan op VM 113 onder `/srv/certs/caddy`. De
proxy vraagt via een afgeschermde ACME-server jaarcertificaten aan en bewaart
eigen serversleutels onder `/srv/proxy/caddy-acme`. Het vertrouwde
rootcertificaat is bij de migratie behouden. De oude CA-privésleutels zijn van
VM 111 verwijderd. De backend-CA blijft op de Forgejo-disk onder
`/srv/forgejo/caddy`; VM 111 vertrouwt het publieke backend-rootcertificaat in
`/srv/proxy/backend-root.crt`. Neem de persistente disks mee in de back-ups.

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
ssh david@192.168.2.113 \
  sudo cat /srv/certs/caddy/.local/share/caddy/pki/authorities/local/root.crt \
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
Forgejo via de browser gebruikt. De publieke CA-sleutel blijft op VM 113. De
geverifieerde rootcertificaten staan centraal in `certs/`. Volg
[Interne certificaten vertrouwen](internal-pki.md) voor NixOS, Debian, Android
en LDAP-containers.

## Forgejo en FreeIPA

FreeIPA draait op `ldap.powerlan.empire` (`192.168.2.101`). De niet-POSIX-groep
`grp-forgejo-user` bepaalt wie via LDAP in Forgejo mag inloggen. Momenteel zijn
`nostradavid` en `poweremperor` lid. De Forgejo-VM vertrouwt de FreeIPA-CA uit
`certs/freeipa.crt`, zodat LDAPS op poort 636 wordt gecontroleerd.

Controleer de verbinding en maak daarna een beperkt LDAP-systeemaccount plus
Forgejo-aanmeldbron aan vanaf het werkstation:

```bash
just forgejo-ldap-check
just forgejo-ldap-bootstrap
```

De bootstrap vraagt interactief om het FreeIPA `admin`-wachtwoord voor een
tijdelijk Kerberos-ticket. Voer dat zelf in; zet het niet in Git of de chat. Het
commando maakt `uid=forgejo-reader,cn=sysaccounts,cn=etc,dc=powerlan,dc=empire`
aan en bewaart het bindwachtwoord alleen op VM 110 in
`/srv/forgejo/ldap-bind-password` (eigenaar `forgejo`, mode `0600`). Opnieuw
uitvoeren gebruikt hetzelfde wachtwoord en werkt de bestaande aanmeldbron bij.

De aanmeldbron zoekt onder `cn=users,cn=accounts,dc=powerlan,dc=empire` en laat
alleen leden van `grp-forgejo-user` toe. LDAP-accounts krijgen niet automatisch
Forgejo-beheerdersrechten. Het lokale adminaccount blijft beschikbaar. Forgejo
synchroniseert LDAP-gebruikers ieder uur; als de groep leeg wordt, mag de
synchronisatie ook alle gebruikers van deze bron deactiveren. Controleer na het
toevoegen of verwijderen van een groepslid de toegang opnieuw, ook via Git over
SSH. Herstart `forgejo` op VM 110 als een nieuw groepslid meteen een
Forgejo-account moet krijgen; anders volgt dit bij de uurlijkse synchronisatie.

## Applicatie entrypoints

De `apps` host verwacht gedeployde applicatie-binaries op:

```text
/opt/huishoudboekje/current/bin/huishoudboekje
/opt/recepten/current/bin/recepten
```

De systemd units gebruiken `ConditionPathIsExecutable`, dus ze worden
overgeslagen zolang de binaries nog niet bestaan.
