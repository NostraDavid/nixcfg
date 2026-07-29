# Bragi met Hyprland starten

Bragi gebruikt een pure Hyprland-sessie. De i3-module en Xserver zijn
uitgeschakeld; `greetd` start Hyprland rechtstreeks voor de hoofdgebruiker. Er
wordt bewust geen uit i3 vertaalde Hyprland-configuratie beheerd.

## Configuratie controleren

Voer vanuit de repository uit:

```bash
nix eval path:.#nixosConfigurations.bragi.config.system.build.toplevel.drvPath --raw
```

Gebruik `path:.` zodat Nix ook nieuwe, nog niet door Git gevolgde bestanden
meeneemt.

## Veilig activeren

Bouw de configuratie eerst voor de volgende boot:

```bash
just boot bragi
sudo reboot
```

Na de herstart meldt `greetd` de hoofdgebruiker automatisch aan en start
Hyprland.

Gebruik voor een onmiddellijke, blijvende activatie:

```bash
just switch bragi
```

Doe dit bij voorkeur vanuit een TTY, omdat het vervangen van de actieve display
manager de bestaande grafische sessie kan beëindigen.

## Persoonlijke Hyprland-configuratie

Deze repository installeert Hyprland, maar schrijft geen
`~/.config/hypr/hyprland.conf`. Voeg alleen een persoonlijke configuratie toe
wanneer dat gewenst is; de i3-configuratie is geen uitgangspunt.

## Herstel

Schakel bij een mislukte grafische start met `Ctrl`+`Alt`+`F2` naar een TTY en
draai de NixOS-generatie terug:

```bash
sudo nixos-rebuild switch --rollback
sudo reboot
```
