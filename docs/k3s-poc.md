# K3s-POC voor eigen apps

K3s 1.36.5+k3s1 draait op VM 106, `prd-svc-k3s-01`, met een declaratieve
NixOS-configuratie. De POC gebruikt één servernode met SQLite voor de
clusteradministratie. Eén testapp bewijst bereikbaarheid, TLS, herstarts en het
ophalen van een geheim uit OpenBao. Er worden geen financiële of andere echte
appgegevens verwerkt.

## Keuze op 25 oktober 2026

Rechtstreeks hosten via NixOS-services of containers is eenvoudiger voor drie
vaste apps. K3s voegt de Kubernetes-API, deployments, namespaces, netwerkbeleid
en healthchecks toe. De keuze voor deze POC sluit aan op de bestaande K3s-VM en
het bouwen van meerdere apps. Een losse server met SQLite is de kleinste
K3s-opzet. Een cluster met meerdere servers op dezelfde fysieke Proxmox-host
levert geen bescherming tegen uitval van die host. De
[K3s-documentatie over datastores](https://docs.k3s.io/datastore) beschrijft
SQLite als standaard voor één server. De
[minimumvereisten](https://docs.k3s.io/installation/requirements) gelden zonder
de capaciteit voor eigen apps.

De oude VM had Debian 12 en K3s 1.31.5, uitsluitend standaardcomponenten en geen
eigen deployments, ingangen of opslagclaims. De gebruiker heeft volledige
vervanging toegestaan. De nieuwe configuratie staat in `hosts/virtual/k3s` en
`features/k3s`; containers en manifests worden door Nix gebouwd.

## Verkeer en adressen

De vier hostnamen verwijzen via Pi-hole naar proxy 111. Caddy vraagt hiervoor
jaarcertificaten aan bij de bestaande CA op VM 113. De proxy stuurt HTTP door
naar Traefik op `192.168.2.106:8080`. Alleen de proxy mag die poort benaderen.
Traefik gebruikt het hostnetwerk; er is geen publiek bereikbare NodePort of
extra TLS-uitgever. De Kubernetes-API op poort 6443 is alleen bereikbaar vanaf
het beheernetwerk en de OpenBao-VM voor tokenvalidatie.

Alle vier adressen tonen voorlopig dezelfde, duidelijk gemarkeerde testapp:

- `https://poc.apps.powerlan.empire/`
- `https://ctb.apps.powerlan.empire/`
- `https://huishoudboekje.apps.powerlan.empire/`
- `https://recepten.apps.powerlan.empire/`

De echte CTB-, huishoudboekje- en receptenapp zijn nog niet uitgerold. Zij
krijgen later ieder een eigen namespace, deployment, geheimbeleid en eventueel
opslag. Alle POC-adressen worden op Homepage geregistreerd, inclusief TLS- en
bereikbaarheidscontrole.

## Geheimen en rechten

De testapp gebruikt serviceaccount `poc` in namespace `apps-poc`. Alleen de
OpenBao-agent krijgt een expliciet geprojecteerd Kubernetes-token dat tien
minuten geldig is. De webcontainer krijgt dit token niet. OpenBao valideert het
via Kubernetes TokenReview en verstrekt korte tokens met uitsluitend leesrechten
op `services/data/k3s/poc`. De kluis bewaart geen langdurig
Kubernetes-reviewertoken. Het serviceaccount mag uitsluitend TokenReviews maken;
het krijgt geen leesrecht op Kubernetes-secrets of clusterbeheer.

De agent schrijft het toepassingsgeheim in een geheugenvolume. De webcontainer
leest dit bestand opnieuw en meldt alleen of een geldig geheim beschikbaar is.
De waarde komt niet in een HTTP-antwoord, Git, een image, de Nix-store of een
Kubernetes Secret. De agent ververst KV-gegevens iedere dertig seconden.
Menselijke wachtwoorden en bestaande OpenBao-policies veranderen niet.

De namespace dwingt de restricted Pod Security Standard af. Containers werken
zonder rootrechten, zonder extra capabilities en met een alleen-lezen
rootbestandssysteem. De netwerkpolicy laat voor deze testapp alleen de ingress
vanaf de node en uitgaand HTTPS naar OpenBao toe. Kubernetes-secrets worden op
de node aanvullend versleuteld met secretbox.

## State en beperkingen

De VM gebruikt twee vCPU's, 4 GiB RAM en twee disks van 32 GiB op
`vm_storage_1`. De NixOS-systeemdisk en persistente K3s-disk zijn gescheiden. De
K3s-disk bevat clusterstate, interne CA's, clustertokens en containerd-data.
Behandel een volledige VM-kopie als beheerderstoegang. De POC bevat geen
applicatiedatabase, uploads of persistente applicatievolumes.

Voor productie zijn een geteste back-up en restore van cluster- en
applicatiedata, databasekeuzes, capaciteitsmetingen en een uitrolprocedure voor
de drie echte apps nodig. De bestaande OpenBao-back-up blijft onafhankelijk. Eén
node en één fysieke Proxmox-host blijven uitvalpunten.

## Beheer en eerste installatie

De gebruiker heeft voor deze POC expliciet toestemming gegeven om Secure Boot
uit te schakelen. De VM start met SeaBIOS en GRUB. De oude Debian-rootdisk en
EFI-disk blijven losgekoppeld bij VM 106 bewaard. Het oorspronkelijke
VM-configuratiebestand staat op de Proxmox-host in
`/root/k3s-before-nixos-20261025.conf`. Herstel met die oude configuratie en
disks vereist een uitgeschakelde VM.

`nix build path:.#k3s-image` bouwt de initiële diskimage. De bestaande VM is
eenmalig via de Proxmox-shell omgezet; er is geen lege OpenTofu-state op de
bestaande infrastructuur toegepast. Na installatie beheert `just deploy-k3s` het
NixOS-systeem, de containers en de Kubernetes-manifests. `just k3s-poc-test`
controleert de HTTP-readiness en geheimenafscherming.

Clusterbeheer verloopt voorlopig op de node via `sudo k3s kubectl`. De beheer-
kubeconfig blijft met modus 0600 op de node. Apps en CI krijgen geen permanente
clusterbeheerderssleutel. De eenmalige OpenBao-inrichting gebruikt de publieke
cluster-CA voor TokenReview en de policy uit `features/k3s/policy.hcl`. Na een
volledige herinstallatie met een nieuwe cluster-CA moet een kluisbeheerder die
trust opnieuw instellen.

## Uitgevoerde acceptatie op 25 oktober 2026

- De node meldt Ready met K3s 1.36.5+k3s1; de POC meldt twee gezonde containers.
  De clusterdata staat op de aparte ext4-disk.
- Alle vier adressen leveren HTTP 200, een geladen OpenBao-geheim en een
  vertrouwd jaarcertificaat. Homepage toont de vier POC-kaarten en TLS-status.
- De POC kan zijn eigen geheim lezen. Een ander serviceaccount kan niet
  aanmelden en de POC kan het Homepage-geheim niet lezen.
- Een gewijzigd testgeheim bereikt de draaiende app zonder podherstart. De
  webcontainer heeft geen Kubernetes-tokenbestand.
- Kubernetes weigert het serviceaccount leesrechten op Secrets. Secretbox staat
  aan; de beheerders-kubeconfig heeft modus 0600. De app-ingang op 8080 en
  Traefik-beheerpoort 9000 zijn vanaf Wodan geblokkeerd.
- Een volledige VM-herstart behoudt de cluster-CA en herstelt K3s en de
  HTTPS-app automatisch. De herstart kan enkele minuten onderbreking geven.
- Na de policywijziging en testrotaties is een kluissnapshot gemaakt. De
  bestaande versleutelde back-up op Wodan is daarna succesvol bijgewerkt.

Een geïsoleerde clusterrestore en back-ups van echte applicatiedata zijn niet
getest; deze POC bevat nog geen applicatiedata.
