{
  config,
  inputs,
  lib,
  repoRoot,
  stable,
  ...
}: let
  community = builtins.fromJSON (builtins.readFile "${inputs.karabiner-rules}/public/json/windows_keyboard_for_mac.json");
  # AltTab handles Option+Tab directly; upstream translates it to app switching.
  keepManipulator = manipulator:
    !((manipulator.from.key_code or "")
      == "tab"
      && builtins.elem "option" (manipulator.from.modifiers.mandatory or []));
  profile = {
    name = "Windows Keyboard for Mac (nixcfg)";
    selected = true;
    complex_modifications.rules =
      map (rule: rule // {manipulators = builtins.filter keepManipulator rule.manipulators;}) community.rules;
  };
  profileSource = config.home.file.".config/nixcfg/karabiner-profile.json".source;
in {
  home.file = {
    ".config/nixcfg/karabiner-profile.json".text = builtins.toJSON profile;
    "Library/Application Support/Code/User/keybindings.json".source =
      config.lib.file.mkOutOfStoreSymlink "${repoRoot}/dotfiles/vscode-1.106.2/.config/Code/User/keybindings.json";
  };

  # Karabiner watches a writable regular file, so merge rather than symlink it.
  home.activation.karabinerProfile =
    lib.hm.dag.entryAfter [
      "linkGeneration"
    ] ''
      if [[ -n "''${DRY_RUN_CMD:-}" ]]; then
        echo "Would update the Windows Keyboard for Mac profile"
      else
        (
          set -euo pipefail
          karabiner_dir=${lib.escapeShellArg "${config.home.homeDirectory}/.config/karabiner"}
          mkdir -p "$karabiner_dir"
          target="$karabiner_dir/karabiner.json"
          temporary=$(mktemp "$karabiner_dir/karabiner.json.XXXXXX")
          trap 'rm -f "$temporary"' EXIT
          if [[ -e "$target" || -L "$target" ]]; then
            cat "$target"
          else
            printf '{"profiles":[]}\n'
          fi | ${stable.jq}/bin/jq --slurp --exit-status --slurpfile profile ${profileSource} \
            --from-file ${./karabiner-profile.jq} > "$temporary"
          if ! cmp -s "$temporary" "$target"; then
            if [[ -e "$target" || -L "$target" ]]; then
              backup=$(mktemp "$karabiner_dir/karabiner.json.nixcfg-backup.XXXXXX")
              cp -p "$target" "$backup"
            fi
            mv -f "$temporary" "$target"
          fi
        )
      fi
    '';
}
