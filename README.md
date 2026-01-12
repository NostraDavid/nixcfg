---
changelog:
  2025-06-27: "initial file"
  2025-07-23: "stabilized on nix flakes"
---
# NostraDavid's nixconfig & dotfiles

I got a `flake.nix` with multiple configurations, which link to a folder in
`hosts/`

## Usage

```bash
# apply the wodan configuration
sudo nixos-rebuild switch --flake .#wodan
```

## Notes

- `docs/` contains script files with nifty commands.
- `hosts/` contains the actual configurations for each host.
- `modules/` contains reusable `configuration.nix` modules.
- `dotfiles/` contains dotfiles for various applications - check `modules/dotfiles.nix` to see how they are symlinked.
- `flake.nix` is the entry point for the whole configuration.
