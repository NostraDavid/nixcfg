# Pi-hole via HTTPS

Pi-hole draait rechtstreeks op VM 102, `192.168.2.102`. De namen `pi.hole` en
`pihole.powerlan.empire` blijven naar deze VM verwijzen. De beheerpagina is
`https://pihole.powerlan.empire/admin/`.

## Certificaat en instellingen

Het servercertificaat is ondertekend door de bestaande interne Caddy-CA uit
`certs/forgejo-ca.crt`. Deze CA wordt ook gebruikt voor Forgejo en OpenBao. De
bestaande Pi-hole-privésleutel blijft op VM 102. Het certificaat bevat:

- `pi.hole`
- `pihole.powerlan.empire`
- `192.168.2.102`

Het certificaat is 365 dagen geldig en wordt automatisch vernieuwd zodra er
minder dan 30 dagen over zijn. De certificaten-VM en Pi-hole controleren dit
dagelijks. De bestaande privésleutel en het certificaat staan samen in
`/etc/pihole/tls.pem`, met behoud van de oorspronkelijke eigenaar en mode
`0600`.

De relevante Pi-hole-instellingen zijn:

```toml
[webserver]
domain = "pihole.powerlan.empire"
port = "80or,443os,[::]:80or,[::]:443os"
serve_all = false

[webserver.tls]
cert = "/etc/pihole/tls.pem"
```

HTTP wordt naar HTTPS doorgestuurd. De canonieke hostnaam verwijst bij `/` naar
`/admin/`. `/var/www/html/index.lp` verzorgt uitsluitend de extra doorverwijzing
van `https://pi.hole/` naar de canonieke beheerpagina. Deze pagina geeft voor
andere hostnamen geen doorverwijzing. De overige toegangsbeveiliging en de
DNS-configuratie blijven behouden.

De aliaspagina gebruikt een browserdoorverwijzing naar de vaste HTTPS-URL. De
pagina bevat alleen voor de verwachte hostnaam deze HTML-doorverwijzing:

```lua
<?
local h = mg.request_info.http_headers or {}
local host = string.lower(h["Host"] or h["host"] or "")
host = string.gsub(host, ":%d+$", "")
if host == "pi.hole" then
  mg.write('<!doctype html><html><head><meta charset="utf-8"><meta http-equiv="refresh" content="0;url=https://pihole.powerlan.empire/admin/"><title>Pi-hole</title></head><body><a href="https://pihole.powerlan.empire/admin/">Open Pi-hole</a></body></html>')
end
?>
```

Bewaar deze openbare pagina met mode `0644`. Schakel `serve_all` niet in voor
deze doorverwijzing.

## Automatische vernieuwing

`features/pihole-tls/default.nix` beheert de uitgever op de certificaten-VM en
de controle op Wodan. De openbare aanvraag staat vast in
`features/pihole-tls/request.csr`. De CA kan hierdoor uitsluitend het
vastgelegde Pi-hole-certificaat publiceren; er is geen aanvraag-API en er zijn
geen nieuwe beheeraccounts of SSH-sleutels. De CA-sleutel blijft op de
certificaten-VM en de serverprivésleutel blijft op Pi-hole.

De dagelijkse volgorde is:

1. Op VM 113 controleert `pihole-tls-publish.timer` vanaf 03:05 of het openbare
   certificaat nog minstens 30 dagen geldig is. Zo nodig ondertekent hij de
   vaste aanvraag voor 365 dagen en publiceert die via
   `https://192.168.2.113/pihole-tls/server.crt`.
2. Op VM 102 controleert `pihole-tls-renew.timer` vanaf 03:15 op een nieuw
   certificaat. De timer haalt gemiste uitvoeringen in en draait ook na boot.
3. `scripts/pihole-tls.py` controleert de CA, alle drie identiteiten,
   servergebruik, geldigheid en overeenkomst met de bestaande privésleutel.
   Alleen een gewijzigde of nog niet geladen uitgifte veroorzaakt installatie en
   een herstart van `pihole-FTL`.
4. Na installatie controleert de helper de daadwerkelijk geserveerde
   certificaatbytes en de aanmeldpagina voor beide namen en het IP-adres. Bij
   een fout zet hij het vorige PEM-bestand terug en controleert ook het herstel.
   Fouten blijven zichtbaar als mislukte systemd-unit.

De schema's gebruiken de lokale tijd van de betreffende VM en een kleine
willekeurige vertraging. Een onbereikbare certificaten-VM verandert geen sleutel
of certificaat; de volgende dagelijkse uitvoering probeert opnieuw. Een echte
vernieuwing vereist een korte Pi-hole-herstart en onderbreekt dan ook DNS.
Ongewijzigde controles herstarten de dienst niet.

Op Wodan controleert `pihole-tls-watch.timer` iedere 15 minuten of Pi-hole de
huidige uitgifte serveert en of die nog minstens 21 dagen geldig is. Een fout
geeft een kritieke desktopmelding via `pihole-tls-alert.service`. Wodan moet
aanstaan voor deze meldingen; de vernieuwing zelf draait zelfstandig op de twee
VM's.

Op Homepage toont Certificaten onder Beheer de Pi-hole-status, resterende dagen
en de leeftijd van de laatste controle. De certificaten-VM werkt
`pihole-tls/status.json` iedere 15 minuten bij. De dagelijkse uitgever en
Pi-hole schrijven bovendien een openbare succes- of foutstatus zonder geheimen.
De bewaking meldt mislukte jobs, een dagelijkse taak die meer dan 48 uur niet
succesvol draaide en een Homepage-status die meer dan twee uur oud is. Een fout
krijgt de status `Fout`.

Het vorige PEM-bestand blijft bewaard en wordt niet ingetrokken. Na de wissel
serveert Pi-hole het nieuwe certificaat. Dezelfde CA, namen en privésleutel
houden het normale clientvertrouwen geldig; bestaande verbindingen kunnen wel
door de korte herstart worden onderbroken.

De Debian-VM gebruikt de native units uit `features/pihole-tls/renew.service` en
`renew.timer`. Bij de eenmalige installatie zijn de helper, units en openbare CA
via vertrouwd HTTPS opgehaald en tegen de hashes van de Nix-bronbestanden
gecontroleerd. De geïnstalleerde paden zijn:

- `/usr/local/libexec/pihole-tls.py`
- `/etc/pihole-tls/ca.crt`
- `/etc/systemd/system/pihole-tls-renew.service`
- `/etc/systemd/system/pihole-tls-renew.timer`

Er zijn geen nieuwe softwareafhankelijkheden op Pi-hole geïnstalleerd. De helper
gebruikt de aanwezige Python, OpenSSL en systemd. Wijzigingen aan helper of
Debian-units moeten ook op VM 102 worden bijgewerkt; Nix publiceert daarvoor
openbare bestanden onder `https://192.168.2.113/pihole-tls/`. Certificaten zelf
worden daarna automatisch opgehaald.

De uitgever weigert te tekenen als de CA niet langer dan 366 dagen geldig is. De
vertrouwde root-CA wordt niet automatisch vervangen. Bewaar zijn sleutel en
herstelstate zoals beschreven in
[intern certificaatvertrouwen](internal-pki.md).

## Controleren en opnieuw proberen

Op Wodan:

```bash
just pihole-tls-test
just pihole-tls-check
systemctl --user status pihole-tls-watch.timer
journalctl --user -u pihole-tls-watch.service
```

Op de certificaten-VM:

```bash
sudo systemctl start pihole-tls-publish.service
systemctl status pihole-tls-publish.timer
journalctl -u pihole-tls-publish.service
```

Op Pi-hole:

```bash
sudo systemctl start pihole-tls-renew.service
systemctl status pihole-tls-renew.timer
journalctl -u pihole-tls-renew.service
openssl x509 -in /etc/pihole/tls.pem -noout -dates -serial
```

De vorige werkende combinatie staat in `/var/lib/pihole-tls/previous.pem`,
root-only met mode `0600`. Het actieve `/etc/pihole/tls.pem` behoudt zijn
Pi-hole-eigenaar en mode `0600`. Beide bevatten privésleutelmateriaal en horen
niet in Git, logs of het openbare publicatiepad.

## Terugzetten

Schakel bij handmatig terugzetten eerst de vernieuwingstimer uit, zodat die de
handmatige wijziging niet opnieuw vervangt:

```bash
sudo systemctl disable --now pihole-tls-renew.timer
```

De oorspronkelijke configuratie en het oude PEM-bestand zijn uitsluitend op de
Pi-hole-VM bewaard onder `/root/pihole-tls-before-powerlan-20261025/`. Deze map
bevat sleutelmateriaal en moet privé blijven. Zet bij herstel beide bestanden
met de juiste oorspronkelijke eigenaar terug en herstart de dienst. Verwijder
bij volledig terugzetten ook de hierboven toegevoegde aliaspagina.

Test beide hostnamen met normale certificaatcontrole, volg de
HTTP-doorverwijzingen tot de beheerpagina en controleer een echte DNS-query.
Controleer ook dat een niet-toegestane hostnaam geen beheerpagina krijgt.

Op 25 oktober 2026 zijn beide certificaatnamen, de HTTP-doorverwijzingen, de
browserdoorverwijzing vanaf `https://pi.hole/` en een echte DNS-query
gecontroleerd. De browser kwam zonder certificaatwaarschuwing uit op de
HTTPS-aanmeldpagina. Andere clientapparaten zijn niet getest.

Bronnen: [Pi-hole TLS](https://docs.pi-hole.net/api/tls/) en
[webserverconfiguratie](https://docs.pi-hole.net/ftldns/configfile/#webserver).
