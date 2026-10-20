---
changelog:
  2025-06-27: "initial file"
  2025-07-23: "stabilized on nix flakes"
  2026-03-08: "add repo direnv basics"
  2026-07-10: "move host composition to flake-parts modules"
---

# NostraDavid's nixconfig & dotfiles

Den composes NixOS, Debian Home Manager, and nix-darwin configurations from
feature-owned aspects. Hosts and users live in `inventory/`; profiles select
features. [Configuration architecture](docs/architecture.md) defines the axes,
dependency rules, public interfaces, and enforced policies.

[The generated module map](docs/module-map.md) shows imports per machine,
optional workstation profiles, unobserved files, and possible absorption
candidates. Run `just module-map` to create the offline interactive diagrams at
`reports/module-map/index.html`. Run `just module-map-check` after module
changes; CI checks the snapshot and uploads the HTML as the `module-map`
artifact.

Run `just architecture-check` to check dependency boundaries and effective host
capabilities. These policies also run during configuration evaluation and CI.
They use evaluated configuration, not only directory names.

## Usage

```bash
# apply the wodan configuration
sudo nixos-rebuild switch --flake .#wodan
```

### Debian and macOS workstations

This flake defines `mimir2` and `loki`. The work repository extends them with
`lib.mkMimir2` and `lib.mkLoki`. See
[Connect a work configuration to nixcfg](docs/work-repo-integration.md) for the
flake input, module hooks, work files, and switch commands.

### Bootstrap a new machine

From a checkout on a standard NixOS installation, add the current machine with:

```bash
./scripts/bootstrap-host.sh donar
```

The script generates the hardware configuration, registers the host, detects a
laptop from its battery, and evaluates the resulting flake. Existing hosts are
never overwritten. The machine type can also be selected explicitly:

```bash
./scripts/bootstrap-host.sh donar laptop
# Or, when `just` is already available:
just bootstrap-host donar laptop
```

### direnv

```bash
direnv allow
```

The default flake dev shell provides Git, Git LFS, and Just to bootstrap a clean
NixOS install. Home Manager installs day-to-day tools; CI obtains its validation
tools separately. Optional local environment variables can live in
`.envrc.local`.

Standalone development tools, formatters, linters, language servers,
vulnerability scanners, and modern CLI utilities follow the pinned unstable
package set. CI uses the same packages through
`legacyPackages.x86_64-linux.unstable`. System components, compiler/runtime
compatibility pairs, and explicit major versions such as Node 24, JDK 17/25,
PostgreSQL 17, and Helm 3 retain their existing package sources. Local release
packages retain their explicit pins.

VS Code uses Ruff from the environment rather than its bundled binary. The
repository's `ruff.toml` shares lint rules with the CLI, selects all stable
rules, and documents exceptions for this script repository. Import sorting,
correctness, and security checks remain enabled. Type annotations are required;
docstrings are optional for now, and assertions are allowed in tests. New stable
rules become active when Ruff is updated. Fixes are opt-in, and unsafe fixes are
disabled unless explicitly requested on the CLI.

After changing package sources, activate the relevant NixOS or Home Manager
configuration and restart the editor's language servers.

cmux is installed on all configured machines: the native GUI from unstable on
macOS, and the official [cmux TUI](https://cmux.com/docs/tui) on Linux,
including servers and the portable Debian profile. Both provide the `cmux`
command, with different interfaces. The local `cmux-tui` package pins an
upstream binary by commit and checksum; refresh it from the official release
manifest when updating.

## Notes

- [OpenCode v2](docs/opencode-v2.md) covers the pinned CLI on all machines, the
  Linux desktop package, configuration compatibility, and migration checks.
- [Windows-style shortcuts on Loki](docs/loki-windows-shortcuts.md) covers
  Karabiner-Elements, AltTab, macOS permissions, and VS Code terminal bindings.
- [Pi and Codex feature checklist](docs/pi-codex-parity.md) covers the shared Pi
  configuration, TypeScript workflow tools, verification, and remaining gaps.
- `docs/` contains script files with nifty commands.
- [Wodan security reports and advisory VEX](docs/security-vex.md) explains the
  raw scan gates and configuration-aware comparison reports.
- [FreeIPA-toegang](docs/freeipa-access.md) beschrijft teams, rechten en de
  gefaseerde toepassing op Forgejo, Proxmox en ingeschreven hosts.
- `inventory/` declares Den hosts and homes, selects their profiles, and owns
  identity, hardware assignments, state versions, and machine overrides.
- `profiles/` composes features into reusable workstation and server profiles.
- `features/` owns each capability's NixOS, Darwin, and Home Manager
  implementations together with its private scripts and helpers.
- `hosts/` and `servers/` contain machine-specific hardware configuration and
  supporting files.
- `nix/` contains package sets, Den evaluation, construction adapters, public
  exports, image outputs, and flake-parts integration.
- `policy/` enforces aspect dependencies, native module provenance, and
  effective capabilities such as Pinta and stable MCP launchers.
- `dotfiles/` contains dotfiles for various applications; the Home Manager
  mappings live in `features/dotfiles/` and `features/terminal-core/`.
- The NixOS construction adapter derives the editable checkout from `repoSubdir`
  (default: `~/dev/NostraDavid/nixcfg/trunk`) and passes it to Home Manager as
  `repoRoot`; a host composition can override `repoSubdir` when its checkout
  lives elsewhere.
- `flake.nix` is the thin entry point for the whole configuration.
