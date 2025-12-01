# Workflow & Process Guidelines

> For architecture and technical patterns, see `.github/copilot-instructions.md`

## Testing Strategy

```bash
sudo nixos-rebuild test --flake .#wodan   # Safe: reverts on reboot
sudo nixos-rebuild boot --flake .#wodan   # Next boot only
nixos-rebuild build-vm --flake .#wodan    # Build VM for risky changes
```

- Always `test` before `switch`
- Use `build-vm` for changes affecting boot, display, or networking
- No flake checks defined yet; if added, run `nix flake check`

## Commit Messages

Short, imperative, lowercase:

- `add k3s manifest`
- `update flake.lock`
- `fix nvidia driver config`

## Pull Requests

Include:

- Scope and affected hosts/modules
- Commands run and results summary
- Screenshots/logs only for UI/service changes

Keep unrelated changes in separate PRs.

## Security

- Never commit secrets; use external secret stores
- Custom certs go in `hosts/<host>/certs/`
- Keep `nix.settings.experimental-features = [ "nix-command" "flakes" ];` enabled
