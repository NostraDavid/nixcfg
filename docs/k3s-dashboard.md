# Headlamp en persoonlijke FreeIPA-aanmelding

Headlamp 0.43.0 draait binnen K3s op VM 106. De ingang is
<https://k3s.powerlan.empire/>. Homepage op VM 103 bevat een dashboardkaart en
een HTTPS-controle. Pi-hole verwijst de hostnaam naar proxy 111; die verzorgt
HTTPS met een automatisch vernieuwd jaarcertificaat van CA 113.

## Aanmelding en identiteit

OpenBao is de OIDC-provider voor Headlamp. Zijn bestaande LDAP-aanmelding
controleert het wachtwoord bij FreeIPA. Dit hergebruikt de bestaande
identiteitskoppeling. Het alternatief Dex zou een extra aanmeldcomponent
vereisen. Er is geen apart dashboardwachtwoord of gedeeld beheertoken.

De aanmeldroute loopt van Headlamp naar de OpenBao-aanmeldpagina en vervolgens
terug naar Headlamp. LDAP is daar de methode voor een eigen FreeIPA-account.
Alleen leden van `grp-infra-admin` mogen deze OIDC-client gebruiken. Kubernetes
controleert bovendien dat de gebruikersnaam op `-adm` eindigt. Een
gebruikersnaam zonder de juiste groep geeft geen toegang. De gebruikersnaamclaim
gebruikt de LDAP-aliasmetadata `name`. De aliasnaam zelf is bij deze
FreeIPA-koppeling een volledige DN en is geen loginnaam.

Bij een geweigerde aanmelding toont de proxy een herstelpagina. Die bevat een
link om bij OpenBao af te melden en een link om een nieuwe Headlamp-aanmelding
te starten. De proxy neemt foutteksten uit de URL niet over. De oorspronkelijke
callback zonder `errors` blijft bij Headlamp, inclusief zijn controles op state
en PKCE.

`poweremperor-adm` en `nostradavid-adm` zijn lid van `grp-infra-admin`, zoals de
bestaande FreeIPA-policy voorschrijft. Een verlopen wachtwoord moet eerst in de
FreeIPA-webinterface worden gewijzigd; OpenBao handelt deze wijziging niet af.
Persoonlijke wachtwoorden blijven buiten de automatische servicerotatie.

De client is publiek en gebruikt verplicht PKCE met S256. Een client-ID is een
publieke identificatie en staat in `features/k3s/headlamp-oidc.json`. Er is geen
clientwachtwoord. De sleutel waarmee OpenBao tokens ondertekent blijft in de
kluis. De eigen RS256-sleutel draait iedere 24 uur; oude openbare sleutels
blijven 24 uur beschikbaar voor verificatie.

OIDC-tokens en Headlamp-cookies zijn vijftien minuten geldig. Cookies zijn
`Secure`, `HttpOnly` en `SameSite=Strict`. Een eigen Traefik-headerregel geeft
HTTPS expliciet door aan Headlamp. De proxy logt de dashboardingang niet, omdat
aanmeldcodes in callback-URL's staan.

FreeIPA-groepswijzigingen worden bij een nieuwe LDAP-aanmelding zichtbaar. Reeds
uitgegeven tokens blijven geldig tot hun verloop. Headlamp en OpenBao hebben
afzonderlijke sessies. Een podherstart kan een lopende aanmelding onderbreken;
een nieuwe aanmelding gebruikt daarna een nieuwe PKCE-poging.

## Kubernetes-rechten

Kubernetes ziet de eigen gebruiker als `freeipa:<gebruikersnaam>` en de groep
als `freeipa:grp-infra-admin`. De dashboardpod krijgt geen aanvullende
Kubernetes-rechten en kan zelf geen workloads of Secrets lezen. De requests van
een aangemelde beheerder gebruiken diens eigen identiteit.

De groep krijgt twee afzonderlijke rollen:

- `headlamp-view` geeft clusterinzage in nodes, namespaces, workloads, logs,
  netwerkobjecten, opslagobjecten en de bestaande CPU- en geheugenmetingen.
- `headlamp-app-operator` geldt uitsluitend in `apps-poc`. Deze rol mag pods
  verwijderen om ze door hun deployment te laten herstellen en aantallen
  replica's aanpassen via de scale-subresources.

Deze rollen geven geen leesrecht op Kubernetes Secrets, geen podterminal en geen
wijzigingen aan RBAC of systeempods. Permanente configuratie blijft in Nix.
Podconfiguratie en logs kunnen toepassingsgegevens bevatten; de leesrol is
daarom beperkt tot de bestaande groep van infrastructuurbeheerders. Een apart
Kubernetes-auditlog valt buiten deze POC. OpenBao registreert de
LDAP-aanmeldingen en tokenuitgifte in zijn bestaande auditvoorziening.

## Declaratieve configuratie en state

`features/k3s/_headlamp.nix` beheert de Nix-container, Kubernetes-objecten,
netwerkpolicy, authenticatieconfiguratie en RBAC. De container werkt zonder
rootrechten, zonder extra capabilities en met een alleen-lezen rootfilesystem.
Headlamp maakt zijn tijdelijke webbestanden in een geheugenvolume. Er is geen
applicatiedatabase of aparte VM nodig.

De netwerkpolicy laat de ingress vanaf de node en uitgaand verkeer naar de
Kubernetes-API, cluster-DNS en OpenBao toe. De bestaande node-firewall laat op
Traefik-poort 8080 alleen proxy 111 toe. Kubernetes-API-poort 6443 houdt de
bestaande toegangsgrenzen.

De OIDC-provider, publieke clientregistratie, groepsalias, assignment en
ondertekeningssleutel staan in OpenBao's Raft-state. Ze vallen onder de
bestaande versleutelde kluissnapshots en kopieën buiten Proxmox. De Nix-tool
`headlamp-identity configure` past uitsluitend deze benoemde configuratie toe.
Hij gebruikt een kort beheertoken via stdin en trekt dat token daarna in. Alleen
publieke clientmetadata verschijnt op stdout. Bestaande FreeIPA- ledenlijsten en
bestaande menselijke OpenBao-policies veranderen niet.

`just deploy-k3s`, `just deploy-proxy`, `just deploy-certs` en
`just deploy-homepage` beheren de uitrol. `just k3s-headlamp-check` controleert
de publieke OIDC-discovery. `just k3s-headlamp-test` controleert dat een
conflicterende bestaande client of groep niet wordt overschreven.

De officiële documentatie beschrijft
[OpenBao als OIDC-provider](https://openbao.org/docs/2.6.x/concepts/oidc-provider/)
en
[Headlamps OIDC-aanmelding](https://headlamp.dev/docs/latest/installation/in-cluster/oidc/).

## Uitgevoerde controles

De live controles bevestigen vertrouwd HTTPS, een jaarcertificaat, de
Homepage-link en de bestaande POC-app. Kubernetes SubjectAccessReviews
bevestigen clusterinzage en POC-bediening, en weigeren Secrets,
RBAC-wijzigingen, systeempods en een podterminal. Het dashboardserviceaccount
kan geen workloads lezen. Een niet-LDAP-onderhoudsidentiteit wordt door de
OIDC-assignment geweigerd.

Een synthetisch ongeldig token bevestigt de cookie-attributen en de weigering
van onbevoegde clusterverzoeken. Vier tests controleren configuratieconflicten
en de LDAP-gebruikersnaamclaim. Daarnaast slagen de Nix-asserties voor
identiteit en rechten en de bestaande monitortests. De OIDC-state en
ondertekeningssleutel zijn opgenomen in de kluissnapshot en de geverifieerde
versleutelde kopie op Wodan.

De persoonlijke LDAP/OIDC-browseraanmeldingen met `poweremperor-adm` en
`nostradavid-adm` zijn live bevestigd. Het accountmenu toont de eigen
gebruikersnaam. Headlamp toont de node, pods en echte CPU- en geheugenmetingen.
De oorspronkelijke DN als gebruikersnaam is vervangen door de loginnaam uit de
aliasmetadata. Er is geen wachtwoord of browsertoken door de configuratietool
gelezen. Een volledige VM-herstart is niet herhaald.
