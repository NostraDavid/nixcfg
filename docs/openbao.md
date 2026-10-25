# Richt OpenBao in naast FreeIPA

Gebruik VM 112, `prd-svc-secrets-01`, op `192.168.2.112`. De VM heeft twee
CPU-cores, 4 GiB geheugen, een systeemdisk van 16 GiB en een datadisk van 16
GiB. De webinterface en API zijn bereikbaar op
`https://openbao.powerlan.empire`. Pi-hole verwijst deze naam naar
`192.168.2.112`. Het certificaat ondersteunt ook het IP-adres en
`secrets.powerlan.empire`. De bestaande clients gebruiken het IP-adres zodat DNS
geen opstartvoorwaarde is.

FreeIPA blijft de accounts en groepen beheren. OpenBao wijzigt dagelijks de
wachtwoorden van `forgejo-reader` en `proxmox-reader`. De afnemers halen iedere
minuut hun eigen wachtwoord op. Een geslaagde LDAP-bind en applicatiecontrole
gaan vooraf aan hun bevestiging aan OpenBao.

Een volledige kopie van de VM bevat ook de lokale sealsleutel. Behandel daarom
de VM, Proxmox-beheerders en volledige VM-back-ups als toegang tot alle
kluisgegevens. Een enkele Proxmox-host biedt geen beschikbaarheid bij
hostuitval.

## Aanmelden

Open `https://openbao.powerlan.empire`, kies **LDAP** en gebruik je eigen
FreeIPA-`-adm`-account met het bijbehorende wachtwoord. De groep
`grp-infra-admin` verleent OpenBao-beheerrechten. Een verlopen
FreeIPA-wachtwoord moet eerst in de FreeIPA-webinterface worden gewijzigd;
OpenBao kan die verplichte wijziging niet afhandelen.

Voor noodtoegang bestaat `recovery-admin` onder de aanmeldmethode **Username**,
met mount path `userpass`. Zijn wachtwoord staat in `initialization.json` binnen
het versleutelde herstelmateriaal. Het is geen FreeIPA-account en valt buiten de
automatische servicerotatie.

## Controleer de configuratie

Voer vanaf de checkout deze controles uit:

```bash
just openbao-check
nix build path:.#checks.x86_64-linux.openbao-image --no-link --print-build-logs
tofu -chdir=infra/openbao validate
just tofu-proxmox-access-check
```

De eerste test gebruikt echte OpenBao- en LDAP-processen. De imagecontrole start
twee geïsoleerde gasten met dezelfde datadisk en verschillende systeemdisks.
Beide controles gebruiken wegwerpgegevens en contacteren de productiedirectory
niet. De applicatiehooks van Forgejo en Proxmox vereisen aanvullende controle
tijdens de productie-uitrol.

## Bereid herstel en de VM voor

1. Controleer in Proxmox dat VM-ID 112 en IP-adres `192.168.2.112` vrij zijn.
2. Gebruik de eigen stapel `infra/openbao`. Bewaar de private API-token in
   `terraform.tfvars` met mode `0600`, volgens het voorbeeld, of geef hem via
   `TF_VAR_proxmox_api_token` door. Deze stapel beheert uitsluitend de nieuwe
   kluis-VM en raakt de bestaande VM-stapel niet aan.
3. Maak op Wodan de onafhankelijke back-upsleutel:

   ```bash
   just openbao-recovery-setup
   ```

4. Bewaar een offline kopie van `~/.local/state/nixcfg/openbao/recovery.agekey`.
   Zet deze privésleutel nooit op Proxmox of in de kluis. Het bestand
   `recipient` bevat alleen de publieke ontvanger en mag naar de VM.
5. Bekijk de VM-wijzigingen en maak de VM aan:

   ```bash
   just openbao-vm-init
   just openbao-vm-plan
   just openbao-vm-apply
   ```

6. Controleer de nieuwe SSH-hostsleutel via de Proxmox-console voordat je hem in
   `known_hosts` opneemt. De SSH-sleutels uit de bestaande VM-configuraties
   geven de gebruiker `david` beheertoegang.
7. Initialiseer en installeer het certificaat:

   ```bash
   just openbao-initialize
   just deploy-proxy
   just openbao-tls
   ```

De eerste opdracht bewaart ook een versleutelde herstelkopie op Wodan. Het
TLS-beheer laat de CA-privésleutel op de certificaten-VM 113. De kluis maakt
zelf zijn eigen privésleutel. Alleen een CSR en het ondertekende certificaat
gaan over het netwerk. Een bestaande, geldige leaf-certificaatsleutel en de
lokale sealsleutel zijn voldoende om zonder de certificaten-VM opnieuw te
starten.

Bewaar lokale noodtoegang tot Proxmox en FreeIPA buiten deze kluis.

## Sluit de twee afnemers aan

Korte onderbreking van nieuwe LDAP-aanmeldingen tijdens rotatie is toegestaan.
Controleer eerst dat je via de Proxmox-console en lokale noodaccounts kunt
herstellen.

1. Maak de beperkte directoryaccount en de ontbrekende bindaccounts:

   ```bash
   just openbao-directory-bootstrap
   ```

   Deze opdracht vraagt een FreeIPA-adminwachtwoord via Kerberos. Hij bewaart
   alleen het initiële rotatorwachtwoord in een privébestand buiten de repo. De
   rotator mag `userPassword` wijzigen voor zichzelf en de twee geselecteerde
   bindaccounts. Hij mag geen gebruikerswachtwoorden of groepsrechten wijzigen.
2. Configureer de kluis en rolverdeling:

   ```bash
   just openbao-configure
   ```

   OpenBao roteert ook zijn eigen directorywachtwoord. Importeer het initiële
   rotatorwachtwoord daarna nooit opnieuw. Herhaald configureren hergebruikt de
   bestaande LDAP-verbinding.
3. Deploy de Forgejo-configuratie met de nieuwe consumer:

   ```bash
   just deploy-forgejo
   ```

4. Zorg op de Proxmox-host voor `python3`, `ldap-utils` en de FreeIPA-realm
   volgens [de toegangsstapel](freeipa-access.md#proxmox). De installer stopt
   als de LDAP-client ontbreekt. Controleer dat bestaande SSH-beheertoegang als
   root werkt en dat de interne CA's in de systeemtrust staan. Neem een al
   bestaande realm eerst over in de OpenTofu-state voordat je de toegangsstapel
   toepast. De OpenBao-VM heeft een eigen, afzonderlijke state.
5. Installeer beide AppRoles en de Proxmox-consumer voordat je rotatie
   activeert:

   ```bash
   just openbao-enroll
   just openbao-activate
   ```

De activatie stopt als een afnemer zijn huidige wachtwoord niet bevestigt. Na
beide bevestigingen trekt OpenBao het initiële root-token in en verwijdert het
de tijdelijke centrale kopieën van de consumercredentials. Vervolgens maakt en
verifieert de opdracht een versleutelde back-up op Wodan.

De AppRole-bootstrapcredentials blijven lokaal in een bestand met mode `0600`.
Zij zijn bewust onbeperkt geldig voor onbeheerde herstarts, maar gelden alleen
vanaf het IP-adres van hun afnemer. De uitgegeven API-tokens zijn vijf minuten
geldig en worden na iedere controle ingetrokken. Een consumer mag alleen zijn
eigen bindwachtwoord lezen en zijn eigen status schrijven.

OpenTofu beheert de Proxmox-realm en ACL's. Het leest geen lokaal
LDAP-bindwachtwoord meer en negeert wijzigingen van `bind_password` tijdens
latere applies. Bestaande state en historische kopieën kunnen het oude geheim
nog bevatten. Bewaar die versleuteld en privé.

## Activeer bewaking op Wodan

Activeer de bijgewerkte Wodan Home Manager-configuratie via de bestaande
uitrolroute. De user-services blijven uit totdat
`~/.local/state/nixcfg/openbao/enabled` bestaat. `openbao-activate` maakt dit
bestand pas nadat een off-host back-up is geverifieerd.

Controleer de services en gezondheid:

```bash
systemctl --user status openbao-backup.timer openbao-watch.timer openbao-tls.timer
just openbao-health
```

De VM maakt ieder uur een consistente Raft-snapshot. Wodan haalt ieder uur de
versleutelde kopie op en controleert of zijn onafhankelijke privésleutel hem kan
ontsleutelen. Kopieën blijven zeven dagen bewaard. Wodan controleert iedere vijf
minuten de kluis en consumerbevestigingen. Een fout geeft een kritieke
desktopmelding en een mislukte user-service. Het certificaat wordt op de eerste
en vijftiende dag van de maand vernieuwd.

Laat Wodan ingeschakeld en zijn user-manager actief voor deze bewaking en
off-host kopieën. Controleer bij een fout de bijbehorende servicejournal.
Wachtwoorden en ontsleutelde back-ups horen niet in logs of terminaluitvoer.

## Herstel geïsoleerd

Een herstelde LDAP-engine kan onmiddellijk wachtwoorden gaan roteren. Verbind
een herstelgast daarom eerst met een geïsoleerd netwerk dat de
productiedirectory en applicaties niet kan bereiken. Een ander IP-adres is geen
afdoende isolatie.

1. Ontsleutel de gekozen back-up op een vertrouwde beheerwerkplek:

   ```bash
   umask 077
   mkdir openbao-restore
   age -d -i ~/.local/state/nixcfg/openbao/recovery.agekey \
     -o openbao-restore/backup.tar /pad/naar/backup.tar.age
   tar -tf openbao-restore/backup.tar
   ```

2. Controleer dat het archief uitsluitend `raft.snap`, `seal.key`,
   `recovery.age`, `backup-credentials.json`, `recipient`, `server.crt` en
   `server.key` bevat. Pak het in de lege herstelmap uit, zonder bestaande
   productiebestanden te overschrijven.
3. Stop OpenBao op de lege herstelgast. Installeer de originele `seal.key` als
   `/srv/openbao/seal/key`, met eigenaar `openbao:openbao` en mode `0400`. Start
   OpenBao opnieuw. Gebruik geen nieuw gegenereerde sealsleutel voor een
   bestaande snapshot.
4. Initialiseer de lege instantie tijdelijk met `bao operator init` en gebruik
   het tijdelijke root-token uitsluitend in de procesomgeving. Herstel daarna
   met `bao operator raft snapshot restore /pad/naar/raft.snap`. Het tijdelijk
   aangemaakte token wordt door de herstelde tokenstaat vervangen.
5. Ontsleutel `recovery.age` met dezelfde onafhankelijke back-upsleutel om bij
   het herstelaccount en de oorspronkelijke recovery shares te komen. Gebruik
   `recovery-admin` via de lokale `userpass`-aanmeldmethode. Recovery shares
   vervangen de verloren static-sealsleutel niet.
6. Herstel de backupcredentials en ontvanger onder `/srv/openbao/ops`. Zet
   `server.crt` en `server.key` uit het archief onder `/srv/openbao/tls`, met
   eigenaar `root:caddy`, mapmode `0750` en sleutelmode `0640`. Daarmee kan
   HTTPS zonder de proxy starten. Vernieuw consumer-AppRoles als lokale
   credentials of afnemers zijn vervangen.
7. Controleer vóór terugkeer naar productie of de directoryverbinding nog werkt.
   Bij een ouder rotatorwachtwoord moet een FreeIPA-beheerder dit account
   herstellen en de LDAP-engine opnieuw verbinden. Hergebruik daarvoor geen oud
   bootstrapbestand.
8. Laat de herstelde kluis de bindwachtwoorden opnieuw roteren. Laat beide
   afnemers de nieuwe waarden toepassen en bevestigen voordat gebruikersverkeer
   terugkeert. Controleer daarna `just openbao-health` en een nieuwe off-host
   back-up.

Een PostgreSQL-verbinding die lokaal zonder wachtwoord werkt, hoeft geen
wachtwoord te krijgen. Proxmox-API-tokenrotatie en persoonlijke wachtwoorden
vallen buiten deze eerste twee integraties.

## Gecontroleerde uitrol op 25 oktober 2026

VM 112 is aangemaakt met de afzonderlijke OpenTofu-stapel. Beide afnemers hebben
twee echte FreeIPA-wachtwoordrotaties doorlopen. De vorige wachtwoorden werden
geweigerd, de nieuwe LDAP-binds en applicatiecontroles slaagden. De AppRoles
konden elkaars geheimen, directoryconfiguratie en snapshots niet lezen. Een
volledige VM-herstart ontgrendelde de kluis automatisch met dezelfde persistente
sealsleutel.

De onafhankelijke sleutel op Wodan ontsleutelt de daadwerkelijke back-up,
inclusief bij elkaar passend TLS-materiaal. Het herstelaccount is getest en het
initiële root-token is aantoonbaar ingetrokken. De uurlijkse off-host back-up en
vijfminutencontrole werken als user-services op Wodan. Tijdelijke Proxmox-API-
en SSH-toegang zijn verwijderd.

De geïsoleerde hersteltest gebruikt wegwerpgegevens. Een offline kopie van de
Wodan-herstelsleutel is niet gecontroleerd. De Proxmox-realm is bij deze uitrol
aangemaakt volgens de toegangsstapel, maar moet bij een eerste latere
access-stack-apply worden overgenomen in diens state.

Pi-hole heeft daarna `openbao.powerlan.empire` naar VM 112 laten verwijzen.
HTTPS en automatische certificaatvernieuwing ondersteunen deze naam. Na
expliciete bevestiging is uitsluitend `poweremperor-adm` toegevoegd aan
`grp-infra-admin`. Het verlopen wachtwoord is door de gebruiker vernieuwd. De
daaropvolgende LDAP-aanmelding bij OpenBao is geslaagd; de OpenBao-audit
bevestigt de policy `openbao-admin`. Andere menselijke accounts zijn hierbij
niet gewijzigd.
