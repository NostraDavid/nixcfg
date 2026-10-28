{fixtureHome}: let
  flake = builtins.getFlake (toString ../.);
  pkgs = flake.legacyPackages.x86_64-linux;
  fixture = flake.inputs.home-manager.lib.homeManagerConfiguration {
    inherit pkgs;
    extraSpecialArgs = {
      inherit (flake) inputs;
      stable = pkgs;
      repoRoot = toString ../.;
    };
    modules = [
      ../features/darwin-keyboard/_home.nix
      {
        home = {
          username = "fixture";
          homeDirectory = fixtureHome;
          stateVersion = "25.11";
        };
      }
    ];
  };
  mac = flake.darwinConfigurations.loki.config;
  work = (flake.lib.mkLoki {username = "work";}).config;
  profile = builtins.fromJSON fixture.config.home.file.".config/nixcfg/karabiner-profile.json".text;
  community = builtins.fromJSON (builtins.readFile "${flake.inputs.karabiner-rules}/public/json/windows_keyboard_for_mac.json");
  count = rules: builtins.length (builtins.concatLists (map (rule: rule.manipulators) rules));
  manipulators = builtins.concatLists (map (rule: rule.manipulators) profile.complex_modifications.rules);
  hasArrow = modifier:
    builtins.any (m: (m.from.key_code or "") == "left_arrow" && (m.from.modifiers.mandatory or []) == [modifier]) manipulators;
in {
  inherit fixture;
  activation = fixture.config.home.activation.karabinerProfile.data;
  checks = {
    packages = assert builtins.all (configuration: !(builtins.any (p: builtins.elem (p.pname or "") ["karabiner-elements-installer" "alt-tab-macos" "rectangle"]) configuration.environment.systemPackages)) [mac work]; true;
    migration = assert mac.system.keyboard.enableKeyMapping && mac.system.keyboard.userKeyMapping == []; assert !(mac.launchd.user.agents ? keyboard-mapping); true;
    homebrew = assert builtins.all (configuration: builtins.all (name: builtins.elem name (map (cask: cask.name) configuration.homebrew.casks)) ["karabiner-elements" "alfred"] && builtins.all (name: !(builtins.elem name (map (cask: cask.name) configuration.homebrew.casks))) ["alt-tab" "rectangle"]) [mac work]; assert mac.nix-homebrew.user == "david" && work.nix-homebrew.user == "work"; true;
    profile = assert profile.selected; assert count profile.complex_modifications.rules == count community.rules - 1; true;
    shortcuts = assert hasArrow "control" && hasArrow "command";
    assert builtins.filter (m: (m.from.key_code or "") == "tab" && builtins.elem "option" (m.from.modifiers.mandatory or [])) manipulators
    == [
      {
        type = "basic";
        from = {
          key_code = "tab";
          modifiers.mandatory = ["option"];
          modifiers.optional = ["shift"];
        };
        to = [{apple_vendor_keyboard_key_code = "mission_control";}];
      }
    ]; true;
    autostart = assert builtins.all (configuration: !(configuration.launchd.user.agents ? alt-tab)) [mac work]; true;
    vscode = assert mac.home-manager.users.david.home.file ? "Library/Application Support/Code/User/keybindings.json"; true;
    linux = assert !(flake.nixosConfigurations.wodan.config.home-manager.users.david.home.file ? ".config/nixcfg/karabiner-profile.json"); true;
  };
}
