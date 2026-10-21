# Windows-style keyboard shortcuts on Loki

Loki installs Karabiner-Elements, AltTab and Rectangle through Homebrew casks
managed by nix-darwin. Homebrew manages their app updates; Nix declares which
apps to install. Activation preserves unrelated Homebrew packages.
BetterTouchTool is not installed.

The
[Windows Keyboard for Mac community edition](https://github.com/Fuzzy-and-Fluffy/windows-keyboard-for-mac)
is pinned through the `karabiner-rules` flake input. It requires **macOS 15 or
newer and Karabiner-Elements 16 or newer**, and applies to all keyboards,
including the built-in MacBook keyboard.

## Activate on the Mac

From the checkout that defines your Loki configuration, run:

```bash
sudo darwin-rebuild switch --flake .#loki
```

Homebrew may request your password to run the Karabiner installer. macOS
permissions still require approval on the Mac.

The activation clears the previous global `hidutil` Control/Command swap and
removes its login agent. Karabiner provides the Windows shortcut translations.
If you changed modifier keys manually in macOS, restore their defaults under
**System Settings > Keyboard > Keyboard Shortcuts > Modifier Keys**.

Open **Karabiner-Elements** and complete its setup prompts. macOS requires you
to allow its background services, Accessibility/Input Monitoring access, and
Driver Extension. These approvals cannot be granted by the Nix configuration.
See the
[Karabiner installation guide](https://karabiner-elements.pqrs.org/docs/getting-started/installation/).

AltTab remains installed, but its login agent is disabled for now. Quit an
already running AltTab once from its menu. Alt+Tab opens Mission Control through
Karabiner instead.

## Managed profile and existing settings

Home Manager selects the **Windows Keyboard for Mac (nixcfg)** profile. It
merges that profile into the writable `~/.config/karabiner/karabiner.json`,
preserves other profiles and global settings, and deselects other profiles.
Before changing an existing file it saves a `karabiner.json.nixcfg-backup.*`
copy alongside it. Invalid JSON or an invalid profiles structure stops
activation without replacing the existing file. Hand-edited JSONC files with
comments must first be converted to plain JSON. Repeating activation with
unchanged data makes no new backup.

The generated profile is also available at
`~/.config/nixcfg/karabiner-profile.json`. Change the repository configuration
instead of editing that managed profile in the Karabiner UI; the next activation
reapplies it. Personal settings in other profiles are retained.

The community rules normally turn Alt+Tab into macOS app switching. We omit
those two forward/backward translations and map physical Alt+Tab and
Alt+Shift+Tab to Mission Control. The remaining community rules are retained.
Rectangle is installed through the Homebrew cask managed by nix-darwin. The
profile uses native macOS window tiling for Win+Arrow, so Rectangle needs no
matching hotkeys.

## Shortcut checks

Use an unsaved text document and a disposable terminal to check the physical
keys after setup:

| Keys                               | Expected behavior                        |
| ---------------------------------- | ---------------------------------------- |
| Ctrl+C / Ctrl+V in an editor       | Copy / paste                             |
| Ctrl+Left / Ctrl+Right             | Move by word                             |
| Ctrl+Shift+Left / Ctrl+Shift+Right | Select by word                           |
| Alt+Tab / Alt+Shift+Tab            | Open Mission Control                     |
| Alt+F4                             | Close the active window                  |
| Win+Left / Win+Right               | Tile the window left / right             |
| Win+Up / Win+Down                  | Native window maximize / restore actions |

The complete coverage is documented in the upstream
[shortcut matrix](https://github.com/Fuzzy-and-Fluffy/windows-keyboard-for-mac/blob/main/docs/shortcut-matrix.md).

## VS Code integrated terminal

Loki links the shared repository keybindings to
`~/Library/Application Support/Code/User/keybindings.json`. Home Manager's
normal `.hm.bak` backup policy applies to an existing unmanaged keybindings
file. The added terminal bindings use `isMac && terminalFocus`, so they do not
affect Linux or editor focus. Existing repository bindings remain in the file.

| Physical keys | Integrated terminal behavior                  |
| ------------- | --------------------------------------------- |
| Ctrl+C        | Send interrupt (`0x03`)                       |
| Ctrl+Shift+C  | Copy the selection                            |
| Ctrl+Shift+V  | Paste                                         |
| Ctrl+V        | Send raw Ctrl+V (`0x16`, shell quoted insert) |

For an interruption check, run `sleep 30` in a disposable integrated terminal
and press Ctrl+C. Then copy and paste harmless selected text without executing
it. These bindings implement the upstream
[VS Code workaround](https://github.com/Fuzzy-and-Fluffy/windows-keyboard-for-mac/blob/main/docs/troubleshooting.md#vs-code-integrated-terminal).

## Verification from Linux

```bash
bash checks/test-loki-keyboard.sh
bash checks/test-work-hosts.sh
```

The keyboard test evaluates Loki and a custom work user, checks Linux isolation,
builds a small Linux Home Manager fixture, and runs the actual profile migration
against temporary files. It covers preserved settings, backups, repeated
activation, invalid input, fresh installation, dry runs, retained arrow rules,
Mission Control mapping and disabled AltTab autostart, and VS Code terminal
bindings. It does not grant macOS permissions or exercise physical keyboard
events; verify those on Loki.
