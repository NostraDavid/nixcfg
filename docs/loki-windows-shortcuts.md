# Loki keyboard and terminal shortcuts

Loki uses the native macOS modifier keys. The global Windows shortcut profile
and its Alt+Tab mapping no longer apply. VS Code still uses the repository's
terminal keybindings: Ctrl+V and Ctrl+Shift+V paste, Cmd+C sends an interrupt,
and Cmd+Shift+C copies the selection.

## Existing installations

Run `just switch` on Loki. If the Homebrew cask is installed, activation runs
the installed driver deactivation script as the Homebrew user, then removes the
cask. If you installed a standalone package instead, open Karabiner-Elements
Settings, select **Uninstall** and launch its uninstaller. macOS can ask for
administrator approval. Complete any driver prompt and restart if macOS requests
it. Personal files under `~/.config/karabiner` remain available.

Check `brew list --cask` and `systemextensionsctl list` after activation.
[Vendor uninstallation instructions](https://karabiner-elements.pqrs.org/docs/manual/operation/uninstall/).

## Checks

```bash
bash checks/test-loki-keyboard.sh
```
