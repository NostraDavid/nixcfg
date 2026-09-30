# Adopt the base workstation module

`base-nixcfg-update.diff` was integrated as an opt-in Home Manager module. The
work repository must import it for both `mimir2` and `loki`:

```nix
extraHomeModules = [
  nixcfg.modules.homeManager.workstation
  ./home/work.nix
];
```

The `workstation` module already includes the `cloud` and `mediaTools` exports.
Do not import those two modules again alongside `workstation`.

## Changes from the raw diff

- The export uses `nixcfg.modules.homeManager`, the interface this base flake
  already uses, instead of `flake.homeModules`.
- The module assumes the base `portable-cli` profile. It does not use
  `profile.useBase` or `profile.packages`. Packages already supplied by
  `portable-cli` are omitted, including Git, Neovim, bat, and Node.js 24. The
  diff's Node.js 26 override is omitted.
- The diff's `direnv` override is omitted. The base profile keeps its existing
  `direnv` settings. The extra Engrim and headroom setup runs only on
  `x86_64-linux`; Linux-only packages keep their platform guards.
- Packages that came from `profile.packages` use base packages where needed. The
  existing agent-memory module already installs Engram and Engrim.
- Wodan, Frigg, `mkMimir2`, and `mkLoki` do not import `workstation`
  automatically. Their existing package choices stay in place.

## Update the work repository

1. Add the import above to both host builders. Keep work-only modules in the
   same `extraHomeModules` list.
2. Remove package entries and Home Manager file mappings now owned by the base
   modules. Keep work-only settings in `home/work.nix`. You no longer need to
   pass `profile` to the base workstation module.
3. Evaluate both hosts and build the `mimir2` activation package before
   switching. Follow the commands in
   [Connect a work configuration to nixcfg](work-repo-integration.md#check-and-apply-the-work-flake).

The base integration built the `mimir2` activation package and evaluated the
`loki` configuration. Neither host had duplicate package outputs when the
workstation module was added to its portable base.
