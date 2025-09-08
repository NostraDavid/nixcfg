# Repository Guidelines

## Project Structure & Modules

- `flake.nix`: Entry point; defines `nixosConfigurations` for hosts (`wodan`, `frigg`).
- `hosts/<host>/`: Per‑host `configuration.nix` plus generated `hardware-configuration.nix`.
- `modules/`: Reusable NixOS/Home‑Manager modules (e.g., `boot.nix`, `programs.nix`).
- `modules/home-manager.nix`: Wires Home‑Manager into each host via `specialArgs`.
- `dotfiles/`: App configs referenced from `modules/dotfiles.nix`.
- `docs/`: Helper scripts (e.g., `nixos-rebuild.sh`, `k3d.sh`).

## Build, Test, and Development

- Switch host config: `sudo nixos-rebuild switch --flake .#wodan`
- Safe test (reverts on reboot): `sudo nixos-rebuild test --flake .#wodan`
- Next‑boot only: `sudo nixos-rebuild boot --flake .#wodan`
- Update inputs: `sudo nix flake update`
- Build a VM: `nixos-rebuild build-vm` (see `docs/nixos-rebuild.sh`).
- Home‑Manager is integrated; no separate `home-manager switch` needed.

## Coding Style & Naming

- Nix files: two‑space indent, trailing semicolons, compact attrs.
- Filenames: lowercase; mirror existing patterns (`boot.nix`, `storage_optimization.nix`).
- Hosts: add under `hosts/<name>/`; keep host‑specific logic out of `modules/`.
- Modules: accept parameters (`{ pkgs, inputs, ... }:`) and avoid global state.
- Format before committing: `alejandra .` (bundled in `home.packages`).

## Testing Guidelines

- Prefer `nixos-rebuild test --flake .#<host>` for validation.
- For risky changes, use `nixos-rebuild build-vm` and boot the VM locally.
- No flake checks defined yet; if added, run `nix flake check` in CI and locally.

## Commit & Pull Requests

- Messages: short, imperative, lowercase (e.g., "add k3s manifest", "update flake.lock").
- PRs should include:
  - Scope and affected hosts/modules.
  - Commands run and results (e.g., test/switch output summary).
  - Screenshots/logs only when UI/services are affected.
- Keep unrelated changes out of the same PR.

## Security & Tips

- Do not commit secrets; prefer external secret stores.
- Minimize manual edits to `hardware-configuration.nix`; regenerate when hardware changes.
- Ensure `nix.settings.experimental-features = [ "nix-command" "flakes" ];` remains enabled on hosts.
