# Bragi i3-starter

Bragi gebruikt i3 als lichte desktop. i3 werkt vooral met sneltoetsen. De
`Super`-toets hieronder is de Windows-toets op de meeste toetsenborden.

## Beginnen

| Actie                     | Sneltoets                                     |
| ------------------------- | --------------------------------------------- |
| Terminal openen           | `Super+Enter`                                 |
| Programma starten         | `Super+d`, typ de programmanaam, druk `Enter` |
| Venster sluiten           | `Super+Shift+q`                               |
| Scherm vergrendelen       | `Super+Shift+l`                               |
| Audio-instellingen openen | `Super+a`                                     |
| i3-configuratie herladen  | `Super+Shift+c`                               |
| i3 opnieuw starten        | `Super+Shift+r`                               |
| Uitloggen                 | `Super+Shift+e`                               |

Start Firefox bijvoorbeeld met `Super+d`, gevolgd door `firefox`.

## Vensters en werkruimtes

- Wissel focus met `Super` en de pijltjestoetsen.
- Verplaats een venster met `Super+Shift` en de pijltjestoetsen.
- Ga naar werkruimte 1–9 met `Super+1` tot en met `Super+9`.
- Verplaats een venster naar een werkruimte met `Super+Shift+1` tot en met
  `Super+Shift+9`.
- Kies horizontale plaatsing met `Super+h` en verticale plaatsing met
  `Super+v`, voordat je het volgende venster opent.
- Wissel tussen tegelweergave en tabbladen met `Super+w`.
- Zet een venster schermvullend met `Super+f`.
- Zet een venster zwevend of weer betegeld met `Super+Shift+Space`.

## Netwerk en geluid

NetworkManager draait op de achtergrond. `nm-applet` staat in de balk en opent
de netwerkkeuzes. Als het pictogram niet bruikbaar is, kan Wi-Fi ook vanuit een
terminal worden beheerd:

```bash
nmcli device wifi list
nmcli device wifi connect "NETWERKNAAM" --ask
```

Gebruik `Super+a` voor de grafische audio-instellingen. De normale volume-,
mute- en schermhelderheidstoetsen zijn ook in i3 ingesteld.

## Terminal

Open een terminal met `Super+Enter`. De tijdelijke minimale Bragi-configuratie
bevat geen Codex, VS Code of algemene ontwikkeltooling. Gebruik zo nodig een
tijdelijke Nix-shell, bijvoorbeeld:

```bash
nix shell nixpkgs#git
```

Zo blijven aanvullende programma's buiten het permanente systeemprofiel.

## Als i3 niet goed start

Schakel met `Ctrl+Alt+F2` naar een tekstconsole, log in en controleer de service:

```bash
systemctl status display-manager
journalctl -b -u display-manager
```

Keer met `Ctrl+Alt+F1` of `Ctrl+Alt+F7` terug naar de grafische sessie. Welke
van deze twee werkt, hangt af van de gebruikte virtuele console.
