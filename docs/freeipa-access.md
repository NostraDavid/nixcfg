# FreeIPA-toegang

`infra/freeipa/policy.toml` is de bron voor teamleden, beheerdersrollen,
FreeIPA-groepen, hostgroepen, HBAC en sudo. De repo is openbaar. Zet dus geen
wachtwoorden of privésleutels in het beleid. Het script maakt directe leden van
de rechtengroepen; LDAP-apps hoeven geen geneste groepen te begrijpen.

| Team               | Leden                                                | Standaardrecht                                 |
| ------------------ | ---------------------------------------------------- | ---------------------------------------------- |
| `team-infra`       | `nostradavid`, `poweremperor`                        | `grp-ro-monitor`: Proxmox-inzage               |
| `team-development` | `nostradavid`, `poweremperor`, `engi`, `ldap_tester` | `grp-forgejo-user`: Forgejo-login              |
| `team-media`       | `mediacenter`                                        | `media-center`: mediabestanden op de datavault |

De rol `platform-admin` bevat uitsluitend `nostradavid-adm` en
`poweremperor-adm`. Zij krijgen direct lidmaatschap van `admins`,
`grp-infra-admin`, `grp-proxmox-admin`, `grp-forgejo-user` en
`grp-forgejo-admin`. FreeIPA's ingebouwde `admin` blijft in `admins` voor
herstel. Bestaande `ipausers`, persoonsgroepen, `engineers` en `editors` vallen
buiten deze reconciliatie.

## FreeIPA toepassen

Vanaf de repo op de beheerwerkplek:

```bash
just freeipa-policy-validate
python3 checks/test-freeipa-policy.py
just freeipa-policy-plan
just freeipa-policy-apply
just freeipa-policy-check
```

`plan`, `apply` en `check` vragen het FreeIPA-adminwachtwoord via `kinit` en
gebruiken een tijdelijk Kerberos-ticket. Het wachtwoord komt niet in Git of in
de uitvoer. `apply` maakt alleen de in het beleid genoemde objecten aan en
herstelt hun directe leden exact. Leden toevoegen gebeurt vóór verwijderen. Als
een account, ingeschreven host of bestaande POSIX-groep ontbreekt, stopt het
script. Een tweede `apply` hoort geen wijzigingen te melden.

Het beleid maakt hostgroepen voor `ldap`, `pihole` en `datavault`. De HBAC- en
sudo-regels laten de twee `-adm`-accounts die hosts beheren. Het ingebouwde
`admin`-account krijgt hersteltoegang op de LDAP-host. Normale accounts krijgen
hierdoor geen SSH of sudo. `allow_all` blijft voorlopig aan. Test vanaf de
consoles en met `ipa hbactest` of beide beheerdersaccounts kunnen inloggen en
sudo gebruiken en of een gewoon account wordt geweigerd. Zet daarna
`settings.enforce_hbac = true` in `policy.toml` en voer `plan` en `apply`
opnieuw uit. Het script toetst de gerichte regels voordat het `allow_all`
uitschakelt. Houd een Proxmox-console en het FreeIPA-`admin`-account beschikbaar
voor herstel.
[FreeIPA HBAC-handleiding](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/managing_idm_users_groups_hosts_and_access_control_rules/configuring-host-based-access-control-rules_managing-users-groups-hosts)

## Forgejo

Voer na de groepswijzigingen `just forgejo-ldap-bootstrap` uit. De aanmeldfilter
gebruikt `grp-forgejo-user`; de adminfilter gebruikt `grp-forgejo-admin`. De
twee `-adm`-accounts hebben een eigen e-mailadres in FreeIPA. Test daarna een
gewone login als `engi` of `ldap_tester`, een adminlogin als elk `-adm`-account
en geweigerde login als `mediacenter`. Controleer intrekking ook via Git over
SSH. Het lokale Forgejo-adminaccount blijft beschikbaar voor herstel.

## Proxmox

De toegangsstapel staat apart van de VM-stapel in `infra/proxmox-access`.
Daarvoor is een eigen API-token nodig met rechten om realms, synchronisatie en
ACL's te beheren. De bestaande VM-token heeft die rechten niet. Om de rol
`Administrator` toe te kennen, moet de tokengebruiker die rechten zelf hebben.
Maak daarom via de Proxmox-console een aparte `ipa-access@pve`-gebruiker met
`Administrator` op `/` en een token `access` met `privsep=0`. Bewaar de token
alleen in de genegeerde `infra/proxmox-access/terraform.tfvars`, op basis van
het `.example`-bestand. Gebruik dit account uitsluitend voor de access-stapel.

```bash
# Op de Proxmox-console, als root:
pveum user add ipa-access@pve
pveum aclmod / -user ipa-access@pve -role Administrator
pveum user token add ipa-access@pve access --privsep=0
```

Maak eerst het beperkte LDAP-zoekaccount en lokale wachtwoordbestand:

```bash
just freeipa-proxmox-reader-bootstrap
```

Het wachtwoord staat daarna in
`~/.local/state/nixcfg/proxmox-ldap-bind-password` met mode `0600`. De nieuwe
OpenTofu-state bevat dit geheim ook en moet daarom privé blijven. Installeer de
publieke FreeIPA-CA uit `hosts/wodan/certs/freeipa.crt` op de Proxmox-host als
`/etc/pve/priv/freeipa-ca.crt` voordat de realm wordt aangemaakt.

```bash
just tofu-proxmox-access-init
just tofu-proxmox-access-tfvars
just tofu-proxmox-access-check
just tofu-proxmox-access-plan
```

Maak eerst alleen de realm aan, bekijk de synchronisatie op de Proxmox-host en
pas daarna de rest toe:

```bash
SSL_CERT_FILE="$PWD/hosts/wodan/certs/proxmox.crt" \
  tofu -chdir=infra/proxmox-access apply -target=proxmox_realm_ldap.freeipa
pveum realm sync freeipa --dry-run 1  # op de Proxmox-host
just tofu-proxmox-access-apply
```

Proxmox synchroniseert alleen de drie genoemde rechtengroepen. Het voegt
`-freeipa` toe aan hun groepsnaam. `grp-ro-monitor-freeipa` krijgt `PVEAuditor`
en `grp-proxmox-admin-freeipa` krijgt `Administrator`, beide op `/`. Een
wijziging in `policy.toml` vernieuwt de realm-synchronisatie bij de volgende
access-stack-apply. Verdwenen LDAP-gebruikers en hun ACL's worden verwijderd bij
die synchronisatie; controleer daarom de dry run vooraf.
[Proxmox-gebruikersbeheer](https://github.com/proxmox/pve-docs/blob/master/pveum.adoc)

Controleer met beide gewone infra-accounts dat zij alleen kunnen lezen en met
beide `-adm`-accounts dat zij volledig kunnen beheren. Test dat `engi` geen
Proxmox-toegang heeft. Behoud `root@pam` voor herstel. Beperk daarna de brede
rechten van de bestaande Terraform-token tot de VM-, node- en opslagpaden die de
VM-stapel nodig heeft, en controleer dit met `just tofu-proxmox-plan`.

## Volgende hosts en diensten

De huidige NixOS-VM's zijn nog niet bij FreeIPA ingeschreven. Sluit ze één voor
één aan nadat de HBAC-regels op de bestaande hosts werken. Test FreeIPA-login en
sudo vóór het terugnemen van de lokale wachtwoordloze `david`-toegang.
Controleer op de datavault welke ACL de bestaande POSIX-groep `media-center`
afdwingt. Pi-hole-webbeheer en toekomstige apps krijgen pas centraal beheer
nadat hun eigen aanmeldroute dat recht ook afdwingt. MFA volgt later, zoals
afgesproken.
