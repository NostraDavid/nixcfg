# HTTPS voor bestaande diensten

Alle links op Homepage gebruiken HTTPS met het bestaande PowerLAN-vertrouwen.
OpenBao op VM 112 is de actieve kluis. De ongebruikte Passvault op VM 107 is
buiten gebruik gesteld: de Homepage-link, proxy-ingang, het DNS-record en de
certificaatvernieuwing zijn verwijderd. Bij de laatste controle was deze oude
Vault niet geïnitialiseerd. VM 107 en zijn twee schijven zijn na aparte
bevestiging verwijderd. De gedeelde Debian-installatie-ISO is behouden.

Home Assistant staat op <https://homeassistant.powerlan.empire/>. Pi-hole wijst
het DNS-record naar `192.168.2.111`. De proxy-ingang en Homepage-link staan in
Nix. Caddy vernieuwt het frontendcertificaat automatisch. Apparaten moeten de
bestaande interne CA vertrouwen.

## Home Assistant

De Home Assistant OS-VM behoudt zijn bestaande HTTP-backend op poort 8123 voor
interne integraties. Browsers gebruiken de HTTPS-proxy. WebSockets lopen via
dezelfde ingang. Alleen `192.168.2.111` staat als vertrouwde proxy ingesteld,
zodat Home Assistant het oorspronkelijke clientadres ontvangt.

Home Assistant 2026.10 beheert HTTP-instellingen in zijn eigen configuratie; een
extra YAML-blok wordt na de eerste migratie genegeerd.
`scripts/home-assistant-proxy.py configure` gebruikt daarom de native
`http/config/configure`-API via de bestaande lokale Supervisor-beheersocket
binnen de Home Assistant-container. Er zijn geen extra accounts of tokens nodig.
De helper behoudt overige HTTP-instellingen en weigert een bestaande,
onbevestigde wijziging te overschrijven.

Home Assistant herstart Core om de instelling te testen. Controleer daarna de
externe HTTPS-ingang en WebSocket-handshake; voer pas daarna dezelfde helper met
`confirm` uit. Dit bevestigt de werkende instelling met `http/config/promote`,
zodat Home Assistant deze bij volgende starts blijft gebruiken. Zonder
bevestiging valt Home Assistant automatisch terug. De oorspronkelijke YAML is
behouden; alleen de native HTTP-instelling is gewijzigd.

## Controle

Voer `python3 checks/test-pihole-tls.py` uit voor de
Pi-hole-certificaatcontroles en herstel bij mislukte vervanging. Controleer
daarnaast de echte HTTPS-adressen, de Homepage-links en de Home Assistant-login
en WebSocket-handshake. Een nieuwe hostnaam heeft een eigen browseraanmelding.
