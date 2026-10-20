# Configuration architecture

Den owns the host, user, home, and aspect composition. Each feature owns its
native configuration and private helpers. Profiles select features; inventory
selects profiles and supplies machine-specific values.

The repository retains flake-parts for package, image, development-shell, and
check outputs. It does not retain the previous internal module registry.

## Axes and responsibilities

| Axis             | Representation                           | Examples                                               |
| ---------------- | ---------------------------------------- | ------------------------------------------------------ |
| Capability       | Den aspect in `features/`                | MCP, annotation, terminal, containers                  |
| Platform         | Den entity system and native class       | x86_64 Linux, Apple Silicon macOS                      |
| Management scope | Aspect class                             | `nixos`, `darwin`, `homeManager`                       |
| Usage context    | Selected inventory and caller extensions | personal desktop, shared portable home, work overrides |

Hosts and profiles compose these axes. They are not additional operating-system
layers. Work configuration extends the shared base through the existing public
factories; personal identity is not added to portable homes.

## Source ownership

| Path                     | Owns                                                              | May depend on                            |
| ------------------------ | ----------------------------------------------------------------- | ---------------------------------------- |
| `features/<capability>/` | Native class modules and private helpers                          | Features, infrastructure                 |
| `profiles/`              | Den `includes` composition                                        | Profiles, features, infrastructure       |
| `inventory/`             | Entities, hardware selection, identity, state versions, overrides | Profiles, features, infrastructure       |
| `hosts/`, `servers/`     | Generated hardware and machine assets                             | Machine hardware dependencies            |
| `nix/`                   | Evaluation, package sources, public adapters, build outputs       | All layers at their explicit boundaries  |
| `policy/`                | Architecture and effective-configuration predicates               | Evaluated model and native configuration |
| `pkgs/`                  | Package recipes and release pins                                  | Package dependencies                     |
| `dotfiles/`              | Native application configuration                                  | Application-specific files               |

Source ownership follows paths. Den's definition metadata identifies the owner
of an aspect; the evaluated Nix graph identifies its implementation imports.
There is no second manually maintained list of host-feature memberships.

An aspect can have multiple native classes. Its private files stay inside the
same feature directory. Select dependencies with Den `includes`; do not import
another feature's private native module. Local features and profiles use named,
concrete aspect references in `includes`. Context-dependent routing belongs to
inventory and infrastructure.

Profiles contain composition only. Identity, `stateVersion`, and device mounts
belong to inventory or generated hardware. Existing USB mounts remain explicitly
selected on the same machines as before the migration.

Native JSON, TOML, and other application settings remain in `dotfiles/`. Home
Manager links those sources and supplies integration. It does not introduce a
second copy of application settings in Den.

## Construction and public interfaces

`nix/evaluate.nix` loads the feature catalogue, profiles, and selected inventory
into one Den evaluation. Den resolves native host and standalone-home modules.
The adapters in `nix/constructors.nix` supply the pinned package sets and invoke
NixOS, nix-darwin, or Home Manager.

The public interfaces remain:

- `lib.mkMimir2 { extraHomeModules = [ ... ]; }`.
- `lib.mkLoki { extraHomeModules; extraDarwinModules; username; homeDirectory; hostname; }`,
  with existing defaults.
- `modules.nixos.*`, `modules.homeManager.*`, and `overlays.default`.
- Existing configuration names, packages, images, and development shells.

Custom factories use the same Den catalogue in an isolated evaluation with the
requested inventory. Public native-module exports resolve those same aspects.
Their cross-class forwarding adapters are external interfaces, not a second
internal composition path.

Standalone tools retain the pinned unstable source. OS/runtime compatibility
packages and explicit major versions retain their established sources. Embedded
Home Manager reuses the OS package set, including the local package projection.
This prevents two differently configured Chromium packages from sharing one user
package environment.

## Enforced contracts

`policy/default.nix` checks aspect ownership, dependency direction, composition
cycles, profile contents, and platform selection. `policy/native.nix` inspects
actual module imports, option-definition provenance, installed packages, and
launcher configuration.

Managed interactive homes require annotation and MCP capabilities. Selecting
annotation must install Pinta. Selecting MCP must deliver all eight local
servers with existing launchers under the configured home directory. Native
Codex launchers remain selected on Wodan, Frigg, and Bragi; CUA remains
disabled. The checks also reject competing Chromium packages in one home
environment.

The policies run at three boundaries:

1. Den evaluation rejects invalid aspect composition.
2. Native configuration assertions reject invalid imports and effective values.
3. `checks.architecture`, `just architecture-check`, hooks, and CI check the
   complete fleet and run negative mutation fixtures.

Local hooks are convenience checks. Enforcing a remote merge gate additionally
requires branch protection with required CI status checks. That repository
setting is not changed by the Nix configuration.

The module map records evaluated native imports. Den composition is available
through `lib.den`; the architecture check evaluates the corresponding policies.
Importing a module alone does not prove that every option inside it is enabled.

## Decision and alternatives

Den is pinned to an inspected revision in `flake.lock`. The current Den project
explicitly distinguishes itself from the strict dendritic pattern. This repo
uses Den's entity and context model, and adopts dendritic's feature ownership
principle without claiming strict conformance to both frameworks.

Two independent designs converged on native Den entities and feature ownership.
The selected design retains thin external adapters and deletes the previous
internal host, role, and Home Manager trees. A library-only Den wrapper over the
old registry was rejected because it would leave two composition mechanisms.

Policy is written in Nix because the evaluated model and effective values are
already available there. OPA would add a separate policy language without a
current cross-project consumer. Formal proofs over an extracted graph would
still depend on the correctness and completeness of the extractor.

Sources: [Den](https://github.com/denful/den),
[dendritic pattern](https://github.com/mightyiam/dendritic), and
[Nix module system](https://nix.dev/tutorials/module-system/).

[Migration validation](architecture-migration.md) records the before/after
comparison, executed checks, and unverified boundaries.
