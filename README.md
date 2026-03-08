---
changelog:
  2025-06-27: "initial file"
  2025-07-23: "stabilized on nix flakes"
  2026-03-08: "add repo direnv basics"
---

# NostraDavid's nixconfig & dotfiles

I got a `flake.nix` with multiple configurations, which link to a folder in
`hosts/`

## Usage

```bash
# apply the wodan configuration
sudo nixos-rebuild switch --flake .#wodan
```

### direnv

```bash
direnv allow
```

The repository now exposes a default flake dev shell, so entering the repo loads
basic Nix tooling like `alejandra`, `just`, `nil`, and `nixd`. Optional local
environment variables can live in `.envrc.local`.

## Notes

- `docs/` contains script files with nifty commands.
- `hosts/` contains the actual configurations for each host.
- `modules/` contains reusable `configuration.nix` modules.
- `dotfiles/` contains dotfiles for various applications - check `modules/dotfiles.nix` to see how they are symlinked.
- `flake.nix` is the entry point for the whole configuration.
