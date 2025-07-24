# NixOS Configuration - AI Coding Agent Instructions

## Architecture Overview

This is a **NixOS Flakes-based configuration** managing multiple hosts with shared components:

- **`flake.nix`**: Entry point defining `nixosConfigurations` for each host (wodan, frigg)
- **`hosts/`**: Host-specific configurations that import shared modules
- **`modules/`**: Reusable NixOS modules (boot, i18n, programs, etc.)
- **`dotfiles/`**: Application configurations organized by package version (e.g., `bash-5.2.37/`)

## Key Patterns

### Module Import Strategy

Host configurations follow this pattern:

```nix
imports = [
  ./hardware-configuration.nix
  ../../modules/boot.nix
  inputs.home-manager.nixosModules.home-manager
  (import ../../modules/home-manager.nix {inherit hostname main-user;})
];
```

### Dotfiles Management via Home Manager

- Dotfiles use **version-specific directories** (`tmux-3.5a/`, `starship-1.23.0/`)
- Symlinked via `modules/dotfiles.nix` using `home.file`
- Structured for compatibility with GNU `stow` (original management tool)

### Parameter Passing

- Uses `specialArgs` in flake to pass `hostname` and `main-user` to configurations
- Modules receive parameters via function arguments: `{hostname, main-user, ...}:`

## Development Workflows

### Configuration Management

```bash
# Apply configuration changes
sudo nixos-rebuild switch --flake .#wodan

# Test changes (reverts on reboot)
sudo nixos-rebuild test --flake .#wodan

# Update flake inputs
sudo nix flake update
```

### Adding New Hosts

1. Create `hosts/HOSTNAME/configuration.nix` and `hardware-configuration.nix`
2. Add entry to `flake.nix` nixosConfigurations
3. Import shared modules using the established pattern

### Package Management

- System packages: Add to `environment.systemPackages` in host configs
- User packages: Add to `home.packages` in `modules/programs.nix`
- Use package overrides for customization (see neovim example with wl-clipboard)

## Project-Specific Conventions

### Hardware-Specific Features

- **wodan**: Gaming rig with NVIDIA drivers, Steam, hardware groups for NuPhy keyboard/Whatpulse
- **frigg**: Different hardware profile, same modular approach

### Security & Certificates

- Custom PKI certificates in `hosts/*/certs/` for enterprise environments
- Firefox configured to trust OS certificate store

### Service Configuration

- K3s with inline manifests using Nix attribute sets
- Prometheus exporters disabled by default (enable per-host)
- Hardware-specific udev rules for peripheral support

## Critical Dependencies

- **NixOS 25.05** channel (stable)
- **Home Manager** for user-level configuration
- **Flakes** experimental feature must be enabled
- Custom certificates for enterprise network integration

When modifying configurations, always test with `nixos-rebuild test` before switching to avoid system breakage.
