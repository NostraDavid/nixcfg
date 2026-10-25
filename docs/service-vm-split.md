# Diensten op afzonderlijke VM's

VM 111 verzorgt de HTTPS-ingangen en Forgejo SSH-doorsturing. Homepage en de
certificaatuitgever draaien op afzonderlijke NixOS-VM's. De configuraties,
images en uitrolcommando's staan in deze repository.

| VM  | Proxmox-naam          | Adres           | Dienst                  |
| --- | --------------------- | --------------- | ----------------------- |
| 111 | `prd-svc-proxy-01`    | `192.168.2.111` | HTTPS en Forgejo SSH    |
| 113 | `prd-svc-certs-01`    | `192.168.2.113` | CA en certificaatbeheer |
| 114 | `prd-svc-homepage-01` | `192.168.2.114` | Homepage                |

`home.powerlan.empire` blijft naar de proxy wijzen. De proxy vraagt Homepage op
VM 114 op poort 3000 op. De Homepage-firewall laat alleen VM 111 op deze poort
toe. `certs.powerlan.empire` wijst rechtstreeks naar VM 113. De bestaande
IP-downloadroutes op VM 111 sturen door naar de certificaten-VM, zodat bestaande
installatiecommando's blijven werken. Forgejo SSH op poort 2222 blijft bij de
proxy horen.

Homepage gebruikt de eerdere reservering 210. Beide disks zijn vóór het starten
van VM 114 volledig vergeleken en identiek bevonden. De oorspronkelijke
sparedisk van 8 GiB is behouden, zonder formatteren of mount. De afzonderlijke,
draaiende VM 103 valt buiten deze migratie.

## Certificaatvertrouwen en vernieuwing

De bestaande vertrouwde root-CA staat op de persistente disk van `certs`, onder
`/srv/certs/caddy/.local/share/caddy/pki/authorities/local/`. De bytes van de
openbare root zijn gelijk aan `certs/forgejo-ca.crt`. Apparaten blijven dezelfde
CA vertrouwen. De oude vertrouwde CA-privésleutels zijn van VM 111 verwijderd.

De proxy gebruikt Caddy's ACME-client tegen
`https://192.168.2.113:8443/acme/local/directory`. De firewall laat uitsluitend
de proxy op poort 8443 toe. De ACME-uitgever staat alleen de bestaande
proxyhostnamen en het IP van VM 111 toe. Certificaten zijn 365 dagen geldig. De
tussenliggende CA is vijf jaar geldig. Eigen serversleutels en ACME-state staan
op de proxy onder `/srv/proxy/caddy-acme`.

Pi-hole houdt zijn eigen privésleutel. Uitgifte en de openbare statusrapportage
draaien op VM 113. Vernieuwing blijft op Pi-hole draaien. OpenBao's bestaande
TLS-onderhoud op Wodan gebruikt eveneens VM 113 als ondertekenaar. Persoonlijke
wachtwoorden, LDAP-rotatie en OpenBao's back-upschema veranderen hierdoor niet.

## State en herstel

De proxy en certificaten-VM gebruiken elk een persistente datadisk van 8 GiB.
Homepage heeft geen eigen gebruikersdatabase en bewaart zijn declaratieve
configuratie op de systeemdisk. Zijn cache is vervangbaar.

De gecontroleerde versleutelde herstelkopie van de vertrouwde CA staat buiten
Proxmox op Wodan:

```text
~/.local/state/nixcfg/certs/ca-before-vm-split-20261025.tar.age
```

De bijbehorende bestaande age-herstelsleutel staat in
`~/.local/state/nixcfg/openbao/recovery.agekey`. Die privésleutel is niet naar
Proxmox verplaatst. De uitrol heeft de herstelkopie ontsleuteld en de root en
sleutel gecontroleerd voordat de CA op VM 113 is geplaatst.

De Caddy-unit van `certs` heeft een startvoorwaarde op `root.key`. Een lege
CA-disk krijgt daardoor geen nieuwe, onbekende CA. Herstel de bestaande CA op de
persistente disk voordat deze dienst kan starten. De vertrouwde root en zijn
bijbehorende sleutel moeten overeenkomen. De tussenliggende CA en openbare
uitgifte kunnen daarna opnieuw worden opgebouwd.

Een oude gecombineerde proxyconfiguratie gebruikt nog `/srv/proxy/caddy`.
Terugrollen naar die configuratie vereist eerst herstel van de oude
CA-privésleutels. Zonder herstel kan Caddy een andere CA maken. De huidige
proxyconfiguratie heeft de vertrouwde CA-privésleutel niet nodig om te starten.

De huidige checkout bevat geen state voor de hoofdstack `infra/proxmox`. De
VM-definities zijn bijgewerkt; een volgende OpenTofu-uitrol vereist eerst
herstel of import van de bestaande resources. Zie
[Proxmox app-VM's](proxmox-app-vms.md). Deze migratie gebruikt de bestaande
Proxmox-beheersessie en maakt geen extra API-account of tijdelijke SSH-toegang.

Eén fysieke Proxmox-host blijft een gezamenlijk uitvalpunt.

## Uitrol en controles

De afzonderlijke uitrolcommando's zijn:

```bash
just deploy-certs
just deploy-homepage
just deploy-proxy
just pihole-tls-check
```

De uitrol op 25 oktober 2026 controleerde volledige herstarts van alle drie
VM's, jaarcertificaten via de centrale ACME-uitgever en de Homepage-links, klok
en certificaatstatus in de browser. OpenBao heeft via de nieuwe ondertekenaar
een certificaat vernieuwd. Pi-hole heeft de nieuwe uitgever gecontroleerd zonder
onnodige DNS-herstart. Een echte Proxmox-shell via de HTTPS-proxy bevestigt dat
de WebSocket-console werkt.
