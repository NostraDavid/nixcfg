# Nixcfg History

This timeline focuses on the structural evolution of the repository.

## Timeline

### June 27, 2025: from a loose NixOS config to a first repository

The repository started simply: first a `README.md`, then one central
`configuration.nix`, followed by a few documentation scripts for
`nixos-rebuild` and channels.

At this point, the repo was mainly a place to capture the current machine
configuration. Everything still lived in one file: applications, Nvidia setup,
automounting, hostname, aliases, and early flakes-related experiments.

The operational workflow was direct and command-oriented. `docs/nixos-rebuild.sh`
acted as a command note for applying the local `configuration.nix`, rebuilding
the system configuration, updating channels, testing changes, staging a boot
configuration, opening the rebuild REPL, building a VM, and inspecting
garbage-collection roots. The important commands were still raw NixOS commands:

- `sudo nixos-rebuild switch -I nixos-config=configuration.nix`
- `sudo nixos-rebuild switch`
- `nix-channel --update`
- `sudo nixos-rebuild test`
- `sudo nixos-rebuild boot`
- `nixos-rebuild build-vm`

### July 19-23, 2025: flakes become the foundation

Around commit `2467bb4`, `flake.nix` and `flake.lock` were added. Shortly after
that, the configuration started moving toward named host configurations. The
real turning point was commit `6806d31`: "move my whole nix config to here, so I
can access it anywhere".

That is the first major shift. From this point, the repository was no longer
just "a NixOS configuration file". It became a real configuration repository
with:

- `hosts/frigg` and `hosts/wodan`
- shared `modules/`
- `dotfiles/`
- Home Manager integration
- certificates per host
- docs and scripts

The repo became portable: the same source tree could now be used across
multiple machines.

The command workflow moved with it. `docs/nixos-rebuild.sh` gained the flake
variant `sudo nixos-rebuild switch --flake .#wodan`, and later
`docs/flake.sh` collected flake-specific notes such as:

- `sudo nixos-rebuild switch --flake .#wodan`
- `sudo nix flake update`
- `nix shell nixpkgs#package`

At this point, the scripts were still mostly memory aids: useful command
collections, but not yet the main command runner for the repo.

### August 2025: dotfiles and daily tooling become part of Nix

After the host/module split, more of the personal user environment became
declarative. Bash, Git, tmux, Starship/Powerline, WezTerm, Vim, and later Neovim
moved under `dotfiles/`.

The important change was not each individual tool. The important change was that
configuration that would normally drift around in `$HOME` became part of the
repo and was linked through `modules/dotfiles.nix`. On August 19, a basic Neovim
configuration was added, bringing the editor setup into the same declarative
system.

### Late August - September 2025: shared and host-specific config become clearer

The distinction between shared configuration and host-specific configuration
became more deliberate. Commit `74ea42e` says this directly: "cleanup
configurations of software that's actually shared".

After that, `modules/storage_optimization.nix` appeared, and features such as
unstable packages, Podman, Redis, `nix-ld`, and host-specific services were
introduced. This was the phase where the repository grew from a desktop package
list into a system-management layer covering storage, services, containers,
binary compatibility, and host behavior.

### September 8, 2025: unstable input becomes structural

Commit `63eb4da` added `nixpkgs-unstable` and started the deliberate use of
stable and unstable packages side by side. This was an important structural
step: from here onward, the repo was no longer just following NixOS stable. It
used a hybrid model where selected tools could come from unstable.

That pattern continued later with tools such as Codex, VS Code, Blender,
Friture, and `devenv`, which moved between stable, unstable, and local packages
depending on freshness and buildability.

### October - November 2025: local packages become their own subsystem

Starting with commit `d527fff`, `pkgs/` became serious with the addition of
`github-copilot-cli`. After that came PixiEditor, nanocoder, bitnet, goose,
opencode, `vscode-pinned`, Synology Drive, and other custom derivations.

The important structural step was commit `2944b84`: "generalized the local pgs
import". That made `pkgs/` less of a collection of one-off hacks and more of an
automatically imported local package layer. The current `flake.nix` still shows
this pattern: directories under `pkgs/` are automatically exposed as packages
and through the local overlay.

### December 2025: first major release upgrade

Commit `c7381d0` moved the repository to NixOS/Home Manager `25.11`. This was
the first real release migration in the history. It required package-name
adjustments and changes to storage optimization settings.

This marked that the repository had become mature enough to be upgraded as a
whole across a NixOS release boundary.

### January 2026: programs get their own top-level structure

Commit `457f8c7` is the second major turning point:
`modules/programs.nix` was split into:

- `programs/shared.nix`
- `programs/wodan.nix`
- `programs/frigg.nix`

Later, `programs/bragi.nix` was added as well.

This made the model clearer: `modules/` contains reusable system modules,
`hosts/` describes machines, and `programs/` describes package choices per
profile or host. That made it easier to treat Wodan, Frigg, and later Bragi
differently without pushing everything into the host configuration files.

### January 26, 2026: a third host is added

Commit `e5d60ad` added `bragi`. The configuration was then quickly refined:
boot-specific pieces were removed, i18n was removed, and a dedicated
`programs/bragi.nix` was added.

This shows that the multi-host model was working. Adding a new host no longer
meant starting over. It meant connecting the host to the existing structure and
then specializing it.

### February 2026: build, cache, and dev-shell maturity

In February, the repository gained more focus on reproducibility and developer
ergonomics:

- `modules/cachix.nix` for faster builds
- additional Cachix tuning
- `direnv` and `devenv`
- Nix language-server configuration
- more local package maintenance tooling

The repository was becoming not only the source of system configuration, but
also the working environment used to maintain that configuration.

### March 8, 2026: desktop configuration becomes more declarative

March 8 was unusually busy and structurally important. `plasma-manager` was
added, KDE/System Settings and desktop entries started becoming declarative, RSS
Guard became declarative, a `Justfile` was introduced, `direnv` was integrated,
and the kernel was pinned.

This is the third major turning point. The repo was no longer only managing the
system and installed packages. It was increasingly managing desktop behavior and
application configuration as well.

The `Justfile` also replaced the old command-note scripts as the repo's real
operational interface. Instead of remembering raw `nixos-rebuild` and flake
commands, the common workflow moved toward recipes such as:

- `just update` for `nix flake update`
- `just test wodan` for `sudo nixos-rebuild test --flake .#wodan`
- `just switch wodan` for `sudo nixos-rebuild switch --flake .#wodan`
- `just boot wodan` for staging a configuration for the next boot
- `just build-vm wodan` for VM builds

That is the command-side version of the same structural story: raw rebuild
commands first, command-note scripts second, flake-specific scripts third, and
finally a proper task runner.

### March - April 2026: maintenance automation and local package lifecycle

Dependabot was added in commit `77ba5d2`, and `cmd/local-package-maint.sh`
followed in commit `7b87e8c`. Local packages now had tooling to check and manage
updates.

This mattered because `pkgs/` became a maintainable subsystem, not just a folder
full of custom Nix files.

The `Justfile` grew with that maintenance model. It added recipes for formatting,
flake inspection, listing package updates, updating one local package, and
updating all local packages. Package maintenance moved from separate update
scripts alone toward a repo-level command surface.

### April 26-29, 2026: self-hosting and infrastructure enter the repo

Commit `61bcace` added VM infrastructure: `hosts/apps`, `hosts/homepage`,
Proxmox VM modules, self-hosted app modules, and documentation. OpenTofu support
then followed under `infra/proxmox`.

Commit `46b0a96` made an important architectural decision: Proxmox/server hosts
moved from `hosts/` to `servers/`, because they did not share the same desktop
and program structure. That produced a cleaner separation:

- `hosts/`: personal machines such as Wodan, Frigg, and Bragi
- `servers/`: app and homepage VMs
- `infra/`: OpenTofu/Proxmox provisioning
- `modules/`: shared building blocks

This is probably the biggest structural step since the initial multi-host flake.

The command interface expanded again here. The `Justfile` gained recipes for app
VM evaluation and deployment, Proxmox OpenTofu initialization, formatting,
validation, planning, applying, inspecting outputs, and checking API-token
permissions through `cmd/proxmox-permissions.sh`. By this point, `just` had
become the control surface not only for rebuilding local machines, but also for
operating the homelab infrastructure.

### May 2026: extra inputs and hardware/application integrations

In May, more external inputs and integrations appeared, including
`codex-desktop-linux`, Blender/LLM/MCP-related tooling, Waydroid, browser
hardware acceleration, and more local packages.

Structurally, the important part is that the flake kept growing as the central
integration point for external projects, unstable tools, and local derivations.

### June 1, 2026: upgrade to 26.05 and cleanup of `pkgs/`

Commit `94ab0c1` moved the repository from `25.11` to `26.05`. Immediately
afterward, commit `64decd5` cleaned up `pkgs/` heavily: unused local packages
were removed, update scripts were added, and package maintenance was tightened.

This feels like the current phase of the repository. It is mature enough that
the work is no longer only about adding things. It also involves maintaining,
migrating, and pruning whole subsystems.

## Overall Story

The repository started as a single NixOS configuration for one machine. Within a
month, it became a flake-based multi-host repository with modules, Home Manager,
and dotfiles. After that, it grew into a declarative personal environment:
shells, editors, desktop configuration, RSS, services, local packages, and
host-specific program profiles.

In early 2026, the structure became more explicit with a dedicated `programs/`
tree and multiple hosts. In March, the repository also became a maintainable
working environment with `Justfile`, `direnv`, Cachix, and declarative desktop
and app configuration. In April, it expanded toward homelab infrastructure with
Proxmox, OpenTofu, and a separate `servers/` tree.

The current repository is therefore no longer a simple dotfiles directory. It is
a combined NixOS, desktop, package-overlay, and homelab-infrastructure
configuration.

The operational path followed the same arc: direct `nixos-rebuild` and
`nix-channel` commands, then docs scripts, then flake-specific scripts, and now
`just update`, `just switch`, and related recipes as the main way to operate the
repo.
