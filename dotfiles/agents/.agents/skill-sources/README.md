# Skillbronnen

Deze map is de geordende bronlaag voor persoonlijke agent-skills. Clients
scannen deze map niet rechtstreeks: Home Manager projecteert iedere skill als
een vlakke symlink onder `~/.codex/skills/<naam>` en/of
`~/.copilot/skills/<naam>`.

| Groep             | Herkomst                        | Skills | Updatebaseline                                                 |
| ----------------- | ------------------------------- | -----: | -------------------------------------------------------------- |
| `codex-system`    | Gebundelde Codex-system-skills  |      5 | Codex CLI `0.144.3`, marker `2575ff8690bf93c7`                 |
| `awesome-copilot` | `github/awesome-copilot`        |     17 | Lokale importcommit `777aa3ef648e19c400a4c371a459210c66017e06` |
| `matt-pocock`     | `mattpocock/skills`             |     22 | Upstream `9603c1cc8118d08bc1b3bf34cf714f62178dea3b`            |
| `local`           | Lokaal geschreven of herontwerp |     13 | Individuele baselines in `local/SOURCE.md`                     |

Lees vóór een update de `SOURCE.md` in de betreffende groep. Daarin staan de
selectie, lokale afwijkingen en synchronisatiegrenzen. De mapping in
`modules/home/dotfiles.nix` is de machineleesbare koppeling van skillnaam naar
herkomstgroep.
