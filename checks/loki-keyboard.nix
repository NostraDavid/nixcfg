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
      ../modules/home/darwin-keyboard.nix
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
    packages = assert builtins.all (configuration: builtins.any (p: (p.pname or "") == "karabiner-elements-installer" && flake.inputs.nixpkgs.lib.versionAtLeast p.version "16.0.0") configuration.environment.systemPackages && builtins.any (p: (p.pname or "") == "alt-tab-macos" && flake.inputs.nixpkgs.lib.versionAtLeast p.version "11.9.2") configuration.environment.systemPackages) [mac work]; true;
    migration = assert mac.system.keyboard.enableKeyMapping && mac.system.keyboard.userKeyMapping == []; assert !(mac.launchd.user.agents ? keyboard-mapping); true;
    homebrew = assert mac.homebrew.casks == [] && work.homebrew.casks == []; assert mac.nix-homebrew.user == "david" && work.nix-homebrew.user == "work"; true;
    profile = assert profile.selected; assert count profile.complex_modifications.rules == count community.rules - 2; true;
    shortcuts = assert hasArrow "control" && hasArrow "command"; assert !(builtins.any (m: (m.from.key_code or "") == "tab" && builtins.elem "option" (m.from.modifiers.mandatory or [])) manipulators); true;
    autostart = assert mac.launchd.user.agents.alt-tab.serviceConfig.RunAtLoad; true;
    vscode = assert mac.home-manager.users.david.home.file ? "Library/Application Support/Code/User/keybindings.json"; true;
    linux = assert !(flake.nixosConfigurations.wodan.config.home-manager.users.david.home.file ? ".config/nixcfg/karabiner-profile.json"); true;
  };
}
