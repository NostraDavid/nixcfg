# NixOS Configuration - AI Coding Agent Instructions

## Architecture

**Flakes-based multi-host NixOS config** with Home Manager integration.

```
flake.nix              # Entry point: mkHost helper, overlay-local for pkgs/
├── hosts/<name>/      # Per-host config + hardware-configuration.nix
├── modules/           # Shared modules imported by hosts
├── pkgs/              # Custom package derivations (auto-discovered via overlay)
└── dotfiles/          # Version-specific configs symlinked via Home Manager
```

**Data flow**: `flake.nix` → `mkHost` passes `hostname`/`main-user` via `specialArgs` → host imports modules → `home-manager.nix` wires user config.

## Commands

```bash
sudo nixos-rebuild switch --flake .#wodan   # Apply changes
sudo nixos-rebuild test --flake .#wodan     # Test (reverts on reboot)
sudo nix flake update                       # Update inputs
alejandra .                                 # Format Nix files before commit
```

## Key Patterns

### Adding Packages

- **System packages**: `environment.systemPackages` in `hosts/<host>/configuration.nix`
- **User packages**: `home.packages` in `modules/programs.nix`
- **Unstable packages**: Use `pkgs-unstable.<pkg>` (see `programs.nix` line 7-10)
- **Local packages**: Add directory to `pkgs/`, automatically picked up via `overlay-local`

### Custom Package Pattern (`pkgs/`)

Packages are auto-discovered. Create `pkgs/<name>/default.nix`:

```nix
{ fetchurl, vscode }: let          # Args from callPackage
  version = "1.106.0";
in vscode.overrideAttrs (_: { inherit version src; })
```

Optional `args.nix` for custom callPackage arguments (see `pkgs/vscode-pinned/`).

### Dotfiles Convention

Version-specific directories (`bash-5.2.37/`, `tmux-3.5a/`) symlinked in `modules/dotfiles.nix`:

```nix
".bashrc".source = mk "${dot}/bash-5.2.37/.bashrc";
```

Structure preserved for GNU `stow` compatibility.

### Module Parameters

Modules receive flake inputs via function args:

```nix
{ pkgs, inputs, hostname, main-user, ... }:
```

## Host-Specific Notes

- **wodan**: NVIDIA + CUDA, Steam, Podman, NuPhy/Whatpulse udev rules, custom certs in `certs/`
- **frigg**: Different hardware, same module pattern

## Conventions

- Two-space indent, trailing semicolons
- Lowercase filenames matching existing patterns
- Format with `alejandra` before committing
- Always `nixos-rebuild test` before `switch`
- Never manually edit `hardware-configuration.nix` unless hardware changes
