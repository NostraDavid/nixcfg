# Proxmox via de interne URL

De beheerinterface staat op <https://proxmox.powerlan.empire/>. HTTP wordt naar
HTTPS doorgestuurd. De link op Homepage gebruikt dit adres.

## Verbinding en vertrouwen

Pi-hole wijst `proxmox.powerlan.empire` naar de bestaande webproxy
`192.168.2.111`. Caddy stuurt de verbinding via HTTPS door naar
`192.168.2.100:8006`. De frontend gebruikt de bestaande PowerLAN-CA en Caddy
vernieuwt het servercertificaat automatisch.

De backendverbinding controleert het IP-adres en de openbare Proxmox-cluster-CA
in `hosts/virtual/proxy/proxmox-ca.crt`. Deze CA is via de geauthenticeerde
beheerverbinding uit `/etc/pve/pve-root-ca.pem` opgehaald en tegen het bestaande
servercertificaat gecontroleerd. De backend kan hierdoor een nieuw
nodecertificaat krijgen zonder dat de proxy aan de oude leaf vastzit. Bij
vervanging van de cluster-CA moet dit openbare bestand worden bijgewerkt. De
privésleutel van de cluster-CA blijft op Proxmox.

Proxmox blijft de accounts, aanmelding en rechten controleren. Een nieuwe
hostnaam krijgt een eigen browseraanmelding. Caddy ondersteunt de WebSockets van
de console en stuurt uploads en console-uitvoer door zonder buffering.
Accesslogging op deze ingang is uitgeschakeld, omdat console-URL's tijdelijke
authenticatietickets bevatten. De normale Proxmox-audit blijft op de host.

Het directe adres <https://192.168.2.100:8006/> blijft beschikbaar voor beheer
en herstel. De bestaande OpenTofu- en onderhoudsroutes blijven dat IP gebruiken.

## Vanaf Wodan

Wodan bevindt zich op `10.0.1.62` achter `10.0.1.1`. De bestaande verbinding
bereikt de webproxy op `192.168.2.111`; er is geen extra portforward nodig.
Wodan gebruikt de DNS-server van zijn router. Die moet het lokale record van
Pi-hole overnemen:

```text
192.168.2.111 proxmox.powerlan.empire
```

Controleer op Wodan:

```bash
getent ahostsv4 proxmox.powerlan.empire
curl --fail --cacert certs/forgejo-ca.crt https://proxmox.powerlan.empire/
```

Apparaten hebben het bestaande [PowerLAN-certificaatvertrouwen](internal-pki.md)
nodig. Test na een wijziging ook een echte aangemelde consoleverbinding.

## Bijwerken

De ingang staat in `hosts/virtual/proxy/default.nix`; de link staat in
`features/homepage/default.nix`. Werk de proxy vanuit deze repo bij:

```bash
just app-vm-check proxy
just deploy-proxy
```

Het DNS-record wordt op de bestaande Pi-hole-VM beheerd. Verander hiervoor geen
Proxmox-hostnaam, clusterconfiguratie of VM-adressen.
