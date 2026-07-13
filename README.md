---
changelog:
  2025-06-27: "initial file"
  2025-07-23: "stabilized on nix flakes"
  2026-03-08: "add repo direnv basics"
  2026-07-10: "move host composition to flake-parts modules"
---

# NostraDavid's nixconfig & dotfiles

The repository uses flake-parts modules to compose multiple NixOS
configurations. Host composition lives in `modules/hosts/`; generated hardware
configuration remains in `hosts/` and `servers/`.

## Usage

```bash
# apply the wodan configuration
sudo nixos-rebuild switch --flake .#wodan
```

### direnv

```bash
direnv allow
```

The repository exposes a default flake dev shell for bootstrapping a clean NixOS
install and running its validation gates. It includes the Nix formatters,
linters, Prek, OpenTofu, and SBOM/vulnerability tooling used by `just` and CI.
Day-to-day editor and language tools are installed through the normal user
profile. Optional local environment variables can live in `.envrc.local`.

## Notes

- `docs/` contains script files with nifty commands.
- `modules/hosts/` contains short host compositions that select hardware,
  roles, features, and host-specific exceptions.
- `modules/roles/` composes reusable machine profiles such as desktops,
  workstations, and Proxmox guests.
- `modules/features/` registers optional capabilities such as laptop power
  management, NVIDIA support, terminal tooling, development, browsers,
  communication, media, gaming, containers, and self-hosted applications.
- `modules/home/` contains the Home Manager implementations registered by those
  features. Wodan-specific extensions use the same capability boundaries.
- `hosts/` and `servers/` contain machine-specific hardware configuration and
  supporting files.
- `modules/` contains the flake-parts entry modules and reusable NixOS and Home
  Manager modules.
- `dotfiles/` contains dotfiles for various applications; the Home Manager
  mappings live in `modules/home/dotfiles.nix` and `modules/home/terminal.nix`.
- `mkHost` derives the editable checkout path from `repoSubdir` (default:
  `~/dev/NostraDavid/nixcfg/trunk`) and passes it to Home Manager as `repoRoot`;
  a host composition can override `repoSubdir` when its checkout lives
  elsewhere.
- `flake.nix` is the thin entry point for the whole configuration.
