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
      extraHomeModules = [./home/work.nix];
    };

    darwinConfigurations.loki = nixcfg.lib.mkLoki {
      extraHomeModules = [./home/work.nix];
    };
  };
}
```

`mkMimir2` accepts `extraHomeModules`. `mkLoki` accepts `extraHomeModules` and
`extraDarwinModules`. Add a Darwin system module only when the work
configuration needs one:

```nix
darwinConfigurations.loki = nixcfg.lib.mkLoki {
  extraHomeModules = [./home/work.nix];
  extraDarwinModules = [./darwin/loki.nix];
};
```

Home Manager modules receive the normal `pkgs`, `lib`, and `config` arguments.
The builders supply `stable`, `unstable`, `hostname`, and `repoRoot` as extra
arguments. They also supply `inputs`, which refers to this base flake's inputs.
Use `pkgs` for packages that must work on both hosts. If a work module needs an
input declared by the work flake, pass it from that flake rather than using the
base `inputs` argument.

The base flake already exports `homeConfigurations."david@mimir2"` and
`darwinConfigurations.loki` for use without a work layer. In the work flake,
call the functions above to add modules before Nix evaluates each host.

## Put work settings in the work repository

Create `home/work.nix`:

```nix
{pkgs, ...}: {
  home.packages = [pkgs.gh];
  home.file.".bashrc.work".source = ../dotfiles/bashrc.work;
  home.file.".config/git/identity.conf".source = ../dotfiles/git/identity.conf;
}
```

Create `dotfiles/bashrc.work` for interactive Bash settings, for example:

```bash
export WORK_REPOS="$HOME/work"
```

The shared `.bashrc` sources `~/.bashrc.work` when it exists. It does so before
`~/.bashrc.local`. Non-interactive Bash sessions return before either file is
sourced. Run the work flake's switch command again after editing this Home
Manager-managed file.

Create `dotfiles/git/identity.conf` with the work Git identity, for example:

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

The portable module already owns these Home Manager file paths:

- Shell: `.bashrc`, `.bash_profile`, `.bash_aliases`, `.bash_aliases-common`,
  `.inputrc`, and `.tmux.conf`.
- Git: `.gitconfig`, `.git-templates`, and `.config/git/` entries for
  `attributes`, `commit-template`, `common.conf`, `hooks`, and `ignore`.
- Editors: `.config/nvim/` and `.vimrc`.
- Other CLI configuration: `.config/bat/config`, `.config/btop/btop.conf`,
  `.config/fastfetch/`, `.config/ghostty/config.ghostty`,
  `.config/starship.toml`, `.config/wezterm/wezterm.lua`, `.config/zigfetch/`,
  `.config/cloc/options.txt`, `.config/dprint/dprint.jsonc`,
  `.config/markdownlint/config.yaml`, `.config/pip/pip.conf`,
  `.config/pypoetry/`, and `.config/uv/uv.toml`.

Remove duplicate mappings for those paths from the work repository before
applying this flake. Move work-only Bash settings into `~/.bashrc.work` and
work-only Git settings into `identity.conf`. If a work setting must replace a
shared file, use `lib.mkForce` on that `home.file` entry in the work module. The
portable module also installs Git, Git LFS, Neovim, uv, direnv, Node.js 24, and
common CLI tools; keep only work-specific packages in the work module.

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
login shell with `dscl . -read /Users/david UserShell`. If the existing account
still uses zsh, run `chsh -s /run/current-system/sw/bin/bash` once and open a
new login session.
