# Warcraft Remastered installeren en spelen

Pas de gaming-configuratie toe met `just switch`.

Installeer beide spellen vanuit de bestaande download:

```sh
warcraft-remastered install
```

Gebruik voor een andere downloadmap
`warcraft-remastered install "/pad/naar/installatiemap"`. Laat de installer
uitpakken en sluit eventuele controlevensters na afloop. Annuleer de aanvullende
DirectX-installer. Beide spellen gebruiken OpenGL via Wine.

Start **Warcraft I Remastered** of **Warcraft II Remastered** vanuit het
applicatiemenu. Vanuit een terminal kan dat met `warcraft-remastered 1` of
`warcraft-remastered 2`. Sluit het actieve spel voordat je het andere start of
opnieuw installeert.

Bewaar voor een back-up de volledige map
`~/.local/share/wineprefixes/warcraft-remastered`. Die bevat de installatie en
de Windows-gebruikersgegevens, waaronder opgeslagen spellen. Bij een aangepaste
`XDG_DATA_HOME` staat de map daar onder `wineprefixes`.

Bekijk bij opstartproblemen de logbestanden in
`~/.local/state/warcraft-remastered`. Bij een aangepaste `XDG_STATE_HOME` staat
de map daar onder `warcraft-remastered`.

Laat de originele download buiten de repository staan. Na een geslaagde
installatie is die download alleen nodig voor herinstallatie. Kopiëren naar
nixcfg of een extra Git-ignore-regel toevoegen is niet nodig.

De launcher gebruikt de klassieke Wine WoW-modus vanwege
[het vastlopen van FreeArc in de nieuwe WoW64-modus](https://list.winehq.org/hyperkitty/list/wine-bugs@list.winehq.org/thread/24ZXNXCQSI547WH3ZPKGETLBDDGQUBFI/).
