# Connect a work configuration to nixcfg

Use this guide in the work repository. This repository owns the shared CLI and
dotfile configuration for `mimir2` and `loki`. The work repository adds settings
through two exported functions; it does not need to import the host modules or
copy their dotfiles.

## Add the base flake

Add `nixcfg` as an input and export the two work configurations. Merge these
declarations into the existing work flake; keep its other work-only inputs and
outputs.

```nix
{
  inputs.nixcfg.url = "github:NostraDavid/nixcfg";

  outputs = {nixcfg, ...}: {
    homeConfigurations."david@mimir2" = nixcfg.lib.mkMimir2 {
      extraHomeModules = [nixcfg.modules.homeManager.workstation ./home/work.nix];
    };

    darwinConfigurations.loki = nixcfg.lib.mkLoki {
      extraHomeModules = [nixcfg.modules.homeManager.workstation ./home/work.nix];
    };
  };
}
```

`mkMimir2` accepts `extraHomeModules`. `mkLoki` accepts `extraHomeModules` and
`extraDarwinModules`. Add a Darwin system module only when the work
configuration needs one:

```nix
darwinConfigurations.loki = nixcfg.lib.mkLoki {
  extraHomeModules = [nixcfg.modules.homeManager.workstation ./home/work.nix];
  extraDarwinModules = [./darwin/loki.nix];
};
```

`mkLoki` also accepts `username`, `homeDirectory`, and `hostname` overrides. It
defaults to `david`, `/Users/david`, and `loki`. If `homeDirectory` is omitted,
it follows the selected username as `/Users/<username>`. This avoids duplicating
the host builder when a Mac uses a different local account or hostname:

```nix
darwinConfigurations.loki = nixcfg.lib.mkLoki {
  username = "alice";
  hostname = "alice-mac";
  # Optional when the account's home is /Users/alice.
  homeDirectory = "/Users/alice";
  extraHomeModules = [nixcfg.modules.homeManager.workstation ./home/work.nix];
};
```

The opt-in `workstation` module includes the cloud and media tools. Do not add
`nixcfg.modules.homeManager.cloud` or `mediaTools` alongside it. See
[Adopt the base workstation module](base-workstation-handoff.md) for the changes
from `base-nixcfg-update.diff` and the work-repository handoff.

For the shared Bash and NDTK changes, follow the
[work-repository shell handoff](work-repo-shell-toolkit-handoff.md).

Home Manager modules receive the normal `pkgs`, `lib`, and `config` arguments.
The builders supply `stable`, `unstable`, `hostname`, and `repoRoot` as extra
arguments. They also supply `inputs`, which refers to this base flake's inputs.
Use `pkgs` for packages that must work on both hosts. If a work module needs an
input declared by the work flake, pass it from that flake rather than using the
base `inputs` argument.

The base flake already exports `homeConfigurations."david@mimir2"` and
`darwinConfigurations.loki` for use without a work layer. In the work flake,
call the functions above to add modules before Nix evaluates each host.

### macOS modifier keys

`mkLoki` imports `modules/darwin-keyboard.nix`, which swaps both left and right
Command and Control keys system-wide, including in terminals. Physical Ctrl+C
sends Cmd+C. To interrupt a terminal process, press physical Cmd+C instead. The
mapping applies during a switch and is restored at login after a reboot.

This swaps modifier keys only. Shortcuts such as Alt+Tab and word navigation
retain their macOS behavior. If the last keyboard is disconnected, macOS can
clear the mapping. Apply the work flake again or log in again to restore it. See
[Apple's key remapping documentation](https://developer.apple.com/library/archive/technotes/tn2450/_index.html).

## Put work settings in the work repository

Create `home/work.nix`:

```nix
{
  home.file.".bash_profile.work".source = ../dotfiles/bash_profile.work;
  home.file.".bashrc.work".source = ../dotfiles/bashrc.work;
  home.file.".bash_aliases.work".source = ../dotfiles/bash_aliases.work;
  home.file.".config/git/identity.conf".source = ../dotfiles/git-2.49.0/identity.conf;
}
```

Create `dotfiles/bash_profile.work` for work-only login settings. The shared
`.bash_profile` sources `~/.bash_profile.work` after `/etc/profile` and
`~/.bashrc`, if the work file exists and is readable. This also applies to
non-interactive login shells. Leave the mapping out if you do not need this
file.

Create `dotfiles/bashrc.work` for interactive Bash settings, for example:

```bash
export WORK_REPOS="$HOME/work"
```

The shared `.bashrc` sources `~/.bashrc.work` when it exists. It does so before
`~/.bashrc.local`. Non-interactive Bash sessions return before either file is
sourced. Run the work flake's switch command again after editing this Home
Manager-managed file.

Create `dotfiles/bash_aliases.work` for work-only aliases. The shared
`.bash_aliases` sources `~/.bash_aliases.work` when it exists, after defining
the shared aliases, so work aliases can override them.

Create `dotfiles/git-2.49.0/identity.conf` with the work Git identity, for
example:

```gitconfig
[user]
    name = David Work
    email = david@work.example
```

The base `~/.gitconfig` includes both the shared `~/.config/git/common.conf` and
the work-owned `~/.config/git/identity.conf`. The base profile does not install
the personal Git identity on either work host. Set the work credential helper in
the work configuration if needed. Keep tokens and passwords out of Git and the
Nix store.

Branch naming is enforced by the shared
[`pre-commit` hook](../dotfiles/git-2.49.0/.config/git/hooks/pre-commit). For
work remotes under `~/dev`, it rejects commits on `main` and `master` and
requires `SOCM-1234-description` or `socm-123-description_with_underscores`. The
ticket number has three or four digits; the description allows letters, digits,
dashes, and underscores. Personal repositories can use `main` and `master`.

The portable module already owns these Home Manager file paths:

- Shell: `.bashrc`, `.bashrc.d/`, `.bash_profile`, `.bash_aliases`, `.inputrc`,
  and `.tmux.conf`.
- Git: `.gitconfig` and `.config/git/` entries for `attributes`,
  `commit-template`, `common.conf`, `hooks`, and `ignore`.
- Editors: `.config/nvim/` and `.vimrc`.
- Other CLI configuration: `.config/bat/config`, `.config/btop/btop.conf`,
  `.config/fastfetch/`, `.config/ghostty/config.ghostty`,
  `.config/starship.toml`, `.config/wezterm/wezterm.lua`, `.config/zigfetch/`,
  `.config/cloc/options.txt`, `.config/dprint/dprint.jsonc`,
  `.config/markdownlint/config.yaml`, `.config/pip/pip.conf`,
  `.config/pypoetry/`, and `.config/uv/uv.toml`.

Remove duplicate mappings for those paths from the work repository before
applying this flake. Move work-only login settings into `~/.bash_profile.work`,
interactive settings into `~/.bashrc.work`, and Git settings into
`identity.conf`. If a work setting must replace a shared file, use `lib.mkForce`
on that `home.file` entry in the work module. The portable module also installs
Git, Git LFS, Neovim, uv, direnv, and Node.js 24. The opt-in workstation module
adds common workstation tools; keep only work-specific packages in the work
module.

## Override agent instructions

The portable module installs the base instruction directory at
`~/.agents/instructions`. Both configurations use its `shared.md`. To add work
rules, create an `AGENTS.md` in the work repository:

```markdown
# AGENTS.md

Read and follow ~/.agents/instructions/shared.md before starting work.

Repository-specific instructions below take precedence over shared instructions
when they conflict.

## Work rules

Add the work repository's instructions here.
```

In `home/work.nix`, override the entrypoint's source. Adjust the checkout path
to the work repository's actual location:

```nix
{config, lib, ...}: {
  home.file."AGENTS.md".source = lib.mkForce (
    config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/work/nixcfg/trunk/AGENTS.md"
  );
}
```

Codex, Pi, OpenCode, and Copilot follow this source automatically. Keep
`~/.agents/instructions` linked to the base checkout. The out-of-store link
allows Qartez to inject its marked section into the work-owned `AGENTS.md`. Keep
that section out of `shared.md` and exclude it when comparing the manually
maintained instructions between repositories. Changes to the shared rules belong
in the base repository. Agent skills and MCP configuration remain separate from
these instruction files.

## Keep the host contract

The builders fix these values:

| Host     | Output                              | Platform                | Home Manager state | Editable base checkout |
| -------- | ----------------------------------- | ----------------------- | ------------------ | ---------------------- |
| `mimir2` | `homeConfigurations."david@mimir2"` | `x86_64-linux`, Debian  | `25.11`            | `/home/david/nixcfg`   |
| `loki`   | `darwinConfigurations.loki`         | `aarch64-darwin`, macOS | `25.11`            | `/Users/david/nixcfg`  |

`loki` also uses nix-darwin 26.05 with `system.stateVersion = 7`. Both builders
configure Home Manager for user `david` and import the shared CLI module. The
`loki` builder configures its macOS hostname and Nix Bash login shell. The
`mimir2` builder only configures Home Manager; it enables the generic Linux
target and disables GPU integration for this CLI profile. Keep those values in
the base flake.

All hosts use `bashInteractive` from the shared pinned `nixpkgs` input. The
macOS builder selects Bash from that input alongside its Darwin package set, so
the system and Home Manager use the same Bash version as Linux. It registers
`/run/current-system/sw/bin/bash` in `/etc/shells` as an allowed login shell.

On Debian, Home Manager installs Bash but does not change the account's login
shell. To use Nix Bash for login, ask an administrator to register the absolute
path to `~/.nix-profile/bin/bash` in `/etc/shells`, then run
`chsh -s "$HOME/.nix-profile/bin/bash"` and open a new login session.

Both hosts link dotfiles to the local `~/nixcfg` checkout. Clone the base repo
at the path in the table. The work flake pins the base Nix code in its
`flake.lock`, while the dotfile links read the local checkout. Keep the checkout
at the pinned revision when you apply a work configuration. Run
`nix flake update nixcfg` in the work repository when you want a newer base
revision. The GitHub input cannot use changes that have not been committed and
pushed from this base repository.

## Check and apply the work flake

From the work-repository checkout on `mimir2`, evaluate and build the profile
before switching:

```bash
nix eval --raw '.#homeConfigurations."david@mimir2".activationPackage.drvPath'
nix build --no-link '.#homeConfigurations."david@mimir2".activationPackage'
home-manager switch --flake '.#david@mimir2'
```

From the work-repository checkout on `loki`, evaluate and build the Darwin
system before switching:

```bash
nix eval --raw '.#darwinConfigurations.loki.config.system.build.toplevel.drvPath'
darwin-rebuild build --flake '.#loki'
sudo darwin-rebuild switch --flake '.#loki'
```

For the first nix-darwin installation on `loki`, use its pinned 26.05 branch
instead of the `darwin-rebuild` command above:

```bash
sudo nix run github:nix-darwin/nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake '.#loki'
```

After switching, check that `~/.bashrc` resolves into the local `~/nixcfg`
checkout, that an interactive Bash session loads `~/.bashrc.work`, and that
`git config --get user.email` returns the work address. On `loki`, check the
login shell with `dscl . -read "/Users/$(id -un)" UserShell`. If the existing
account does not use `/run/current-system/sw/bin/bash`, run
`chsh -s /run/current-system/sw/bin/bash` once and open a new login session. Run
`echo "$BASH_VERSION"` in that session to check the active Bash version.
