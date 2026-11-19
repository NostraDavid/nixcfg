let
  flake = builtins.getFlake (toString ../.);
  mac = flake.darwinConfigurations.loki.config;
  work = (flake.lib.mkLoki {username = "work";}).config;
  configs = [mac work];
  temp = builtins.getEnv "LOKI_KEYBOARD_FIXTURE";
  migration =
    (import ../features/darwin-keyboard/_darwin.nix {
      inherit (flake.inputs.nixpkgs) lib;
      config.homebrew = {
        prefix = temp + "/brew";
        user = "fixture";
      };
    }).system.activationScripts.homebrew.text.content;
  inherit (builtins) all;
  home = c: c.home-manager.users.${c.system.primaryUser};
in {
  fixture = builtins.replaceStrings ["/Library/Application Support/org.pqrs" "/usr/bin/sudo"] [(temp + "/support") (temp + "/sudo")] migration;
  checks = {
    homebrew = assert all (c: let
      casks = map (cask: cask.name) c.homebrew.casks;
    in
      c.homebrew.enable && c.homebrew.onActivation.cleanup == "none" && builtins.elem "alfred" casks && !(builtins.elem "karabiner-elements" casks) && !(builtins.elem "alt-tab" casks))
    configs;
    assert mac.nix-homebrew.user == "david" && work.nix-homebrew.user == "work"; true;
    packages = assert all (c:
      !(builtins.any (p: builtins.elem (p.pname or "") ["karabiner-elements" "karabiner-elements-installer" "alt-tab-macos"]) c.environment.systemPackages))
    configs; true;
    keyboard = assert all (c: c.system.keyboard.enableKeyMapping && c.system.keyboard.userKeyMapping == [] && !(c.launchd.user.agents ? keyboard-mapping) && !(c.launchd.user.agents ? alt-tab)) configs; true;
    vscode = assert all (c: (home c).home.file ? "Library/Application Support/Code/User/keybindings.json" && !((home c).home.activation ? karabinerProfile)) configs; true;
  };
}
