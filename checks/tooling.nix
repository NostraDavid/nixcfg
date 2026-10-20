let
  flake = builtins.getFlake (toString ../.);
  lib = flake.inputs.nixpkgs.lib;
  unstableFor = system:
    import flake.inputs.nixpkgs-unstable {
      inherit system;
      config.allowUnfree = true;
    };
  wodan = flake.nixosConfigurations.wodan.config.home-manager.users.david;
  mimir2 = flake.homeConfigurations."david@mimir2".config;
  loki = flake.darwinConfigurations.loki.config.home-manager.users.david;
  linuxWorkstation =
    (flake.lib.mkMimir2 {
      extraHomeModules = [flake.modules.homeManager.workstation];
    }).config;
  darwinWorkstation =
    (flake.lib.mkLoki {
      extraHomeModules = [flake.modules.homeManager.workstation];
    }).config.home-manager.users.david;
  checkSources = system: home: names: let
    pkgs = unstableFor system;
    installed = map (p: p.outPath) home.home.packages;
  in
    assert lib.all (name: lib.assertMsg (builtins.elem pkgs.${name}.outPath installed) "Expected unstable.${name} in ${system} tooling profile") names; true;
  cliTools = ["actionlint" "lnav" "nix-index" "nix-tree" "nvd" "watchexec"];
  core = ["git" "git-lfs" "just" "ast-grep" "mergiraf" "fd" "fzf" "bat" "hurl" "lsd" "sqruff" "starship" "tmux" "tree" "worktrunk"] ++ cliTools;
  workstation = ["ruff" "prek" "dprint" "shellcheck" "shfmt" "nixd" "pyrefly" "markdownlint-cli" "sbomnix" "grype" "opentofu" "sqlfluff" "jq"];
  stable = flake.nixosConfigurations.wodan.pkgs;
  installed = map (p: p.outPath) wodan.home.packages;
in {
  nixIndexInitialization = assert lib.all (home: home.home.activation ? nixIndex) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  macosTimeout = assert lib.all (home: toString home.home.file.".local/bin/timeout".source == "${(unstableFor "aarch64-darwin").coreutils}/bin/timeout" && lib.hasSuffix "-gtimeout" (toString home.home.file.".local/bin/gtimeout".source)) [loki darwinWorkstation]; assert !(mimir2.home.file ? ".local/bin/timeout"); true;
  macosSpeech = assert lib.all (home: lib.all (name: builtins.any (p: (p.pname or "") == name) home.home.packages) ["espeak-ng" "piper-tts" "coreutils" "gnused"] && lib.all (path: builtins.hasAttr path home.home.file) [".local/bin/say" ".local/bin/say-piper-tts" ".config/say/espeak-ng-data" ".config/say/piper.sed" ".local/share/piper-voices/nl_NL-pim-medium.onnx" ".local/share/piper-voices/nl_NL-pim-medium.onnx.json"]) [loki darwinWorkstation]; true;
  physicalTools = assert lib.all (name: checkSources "x86_64-linux" flake.nixosConfigurations.${name}.config.home-manager.users.david (["hurl" "sqruff" "worktrunk"] ++ cliTools)) ["wodan" "donar" "frigg" "bragi"]; true;
  worktrunkSkills = assert lib.all (home: lib.all (client: home.home.file.".${client}/skills/worktrunk".source == home.home.file.".agents/skills/worktrunk".source) ["codex" "copilot" "config/opencode" "pi/agent"]) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  playwrightCli = assert builtins.elem stable.playwright-cli.outPath installed; assert lib.all (path: toString wodan.home.file.${path}.source == "${stable.playwright-cli}/share/skills/playwright-cli") [".agents/skills/playwright-cli" ".codex/skills/playwright-cli" ".copilot/skills/playwright-cli" ".config/opencode/skills/playwright-cli"]; assert lib.all (host: host.config.networking.hostName == "wodan" || !(builtins.any (p: (p.pname or "") == "playwright-cli") (host.config.home-manager.users.david.home.packages or []))) (builtins.attrValues flake.nixosConfigurations); true;
  browserMcp = assert lib.all (package: builtins.elem package.outPath installed) [stable.chrome-devtools-mcp (unstableFor "x86_64-linux").playwright-mcp]; assert lib.all (host: host.config.networking.hostName == "wodan" || !(builtins.any (p: builtins.elem (p.pname or "") ["chrome-devtools-mcp" "playwright-mcp"]) (host.config.home-manager.users.david.home.packages or []))) (builtins.attrValues flake.nixosConfigurations); true;
  workMcp = assert lib.all (home: lib.all (name: builtins.any (package: (package.pname or "") == name) home.home.packages) ["chrome-devtools-mcp" "mcp-nixos" "playwright-mcp"]) [mimir2 loki linuxWorkstation darwinWorkstation]; true;
  dbhub = assert builtins.elem stable.dbhub.outPath installed; assert lib.all (host: host.config.networking.hostName == "wodan" || !(builtins.any (p: (p.pname or "") == "dbhub") (host.config.home-manager.users.david.home.packages or []))) (builtins.attrValues flake.nixosConfigurations); assert !(builtins.any (p: (p.pname or "") == "dbhub") (loki.home.packages ++ mimir2.home.packages)); true;
  nixosMcp = assert builtins.elem (unstableFor "x86_64-linux").mcp-nixos.outPath installed; assert wodan.home.activation ? wodanMcpClients; assert lib.all (host: host.config.networking.hostName == "wodan" || !(host.config ? home-manager.users.david.home.activation.wodanMcpClients)) (builtins.attrValues flake.nixosConfigurations); assert !(loki.home.activation ? wodanMcpClients); assert !(mimir2.home.activation ? wodanMcpClients); true;
  opencode = assert lib.all (host: builtins.elem host.pkgs.opencode-v2.outPath (map (p: p.outPath) host.config.environment.systemPackages)) (builtins.attrValues flake.nixosConfigurations); assert builtins.elem stable.opencode-v2.outPath (map (p: p.outPath) mimir2.home.packages); assert builtins.any (p: (p.pname or "") == "opencode-v2" && lib.hasPrefix "2." p.version) loki.home.packages; assert builtins.elem stable.opencode-v2-desktop.outPath installed; assert !(builtins.any (p: lib.hasPrefix "opencode" (p.pname or "") && lib.hasPrefix "1." (p.version or "")) (wodan.home.packages ++ linuxWorkstation.home.packages ++ darwinWorkstation.home.packages)); true;
  cmux = assert lib.all (host: builtins.elem host.pkgs.cmux-tui.outPath (map (p: p.outPath) host.config.environment.systemPackages)) (builtins.attrValues flake.nixosConfigurations); assert builtins.elem stable.cmux-tui.outPath (map (p: p.outPath) mimir2.home.packages); assert builtins.elem (unstableFor "aarch64-darwin").cmux.outPath (map (p: p.outPath) loki.home.packages); assert builtins.any (p: (p.pname or "") == "cmux-tui" && p.system == "aarch64-darwin" && (p.meta.priority or 5) < ((unstableFor "aarch64-darwin").cmux.meta.priority or 5)) loki.home.packages; true;
  wodan = checkSources "x86_64-linux" wodan (core ++ builtins.filter (name: name != "opentofu") workstation ++ ["lua-language-server"]);
  debian = checkSources "x86_64-linux" mimir2 core;
  macos = checkSources "aarch64-darwin" loki core;
  debianWorkstation = checkSources "x86_64-linux" linuxWorkstation (core ++ workstation);
  macosWorkstation = checkSources "aarch64-darwin" darwinWorkstation (core ++ workstation);
  helmCompatibility = assert builtins.elem stable.kubernetes-helm.outPath (map (p: p.outPath) linuxWorkstation.home.packages); true;
  direnv = assert wodan.programs.direnv.package.outPath == (unstableFor "x86_64-linux").direnv.outPath; assert wodan.programs.direnv.nix-direnv.package.outPath == (unstableFor "x86_64-linux").nix-direnv.outPath; true;
  compatibilityPins = assert lib.all (package: builtins.elem package.outPath installed) [stable.nodejs_24 stable.gcc stable.gcc-unwrapped stable.openjdk25 stable.postgresql stable.kubernetes-helm]; true;
}
