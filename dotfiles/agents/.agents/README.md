# Lokaal beheerde skillbronnen

Deze map bevat de lokale skills, elk in een eigen map. Lees
[`SOURCE.md`](SOURCE.md) voor herkomst en updategrenzen.

Awesome Copilot, Matt Pocock, PStack en Polars komen rechtstreeks uit
Nix-inputs, zonder lokale kopieën. Hun selecties staan in
`pkgs/*-skills/skills.nix`.

Clients scannen deze bronmap niet rechtstreeks. `modules/home/dotfiles.nix`
selecteert de skills en koppelt ze afzonderlijk naar Codex, Copilot en OpenCode.
Zie [het overzicht](../README.md) voor updates.
