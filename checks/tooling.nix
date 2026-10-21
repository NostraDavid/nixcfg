let
  flake = builtins.getFlake (toString ../.);
  lib = flake.inputs.nixpkgs.lib;
  unstableFor = flake.lib.unstableFor;
  wodan = flake.nixosConfigurations.wodan.config.home-manager.users.david;
  mimir2 = flake.homeConfigurations.mimir2.config;
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
  cliTools = [
    "actionlint"
    "lnav"
    "nix-index"
    "nix-tree"
    "nvd"
    "watchexec"
  ];
  core =
    [
      "ast-grep"
      "bat"
      "fd"
      "fzf"
      "git-lfs"
      "git"
      "hurl"
      "just"
      "lsd"
      "mergiraf"
      "sqruff"
      "starship"
      "tmux"
      "tree"
      "worktrunk"
    ]
    ++ cliTools;
  workstation = [
    "dprint"
    "grype"
    "jq"
    "markdownlint-cli"
    "nixd"
    "opentofu"
    "prek"
    "pyrefly"
    "ruff"
    "sbomnix"
    "shellcheck"
    "shfmt"
    "sqlfluff"
  ];
  stable = flake.nixosConfigurations.wodan.pkgs;
  installed = map (p: p.outPath) wodan.home.packages;
in {
  fleetFonts = let
    fonts = (import ../features/fonts/default.nix {}).den.aspects.fonts;
    systems = builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations;
    homes =
      builtins.attrValues flake.homeConfigurations
      ++ lib.concatMap (host:
        map (config: {
          inherit config;
          inherit (host) pkgs;
        }) (builtins.attrValues (host.config.home-manager.users or {})))
      systems;
    hasFonts = pkgs: packages:
      lib.all (font: builtins.elem font.outPath (map (p: p.outPath) packages)) (fonts.nixos {inherit pkgs;}).fonts.packages;
  in
    assert lib.all (host: hasFonts host.pkgs host.config.fonts.packages) systems;
    assert lib.all (home: hasFonts home.pkgs home.config.home.packages && (home.pkgs.stdenv.hostPlatform.isLinux -> home.config.fonts.fontconfig.enable)) homes; true;
  terminalEmulators = assert lib.all (host: let
    inherit (host) pkgs;
    unstable = unstableFor pkgs.stdenv.hostPlatform.system;
    packages = map (p: p.outPath) host.config.home-manager.users.david.home.packages;
  in
    lib.all (name: lib.any (source: builtins.elem source.${name}.outPath packages) [pkgs unstable]) [
      (
        if pkgs.stdenv.hostPlatform.isDarwin
        then "ghostty-bin"
        else "ghostty"
      )
      "alacritty"
      "kitty"
      "msedit"
    ]) [flake.nixosConfigurations.wodan flake.darwinConfigurations.loki]; true;
  portableWorkstationPackages = assert lib.all (profile: let
    inherit (profile) pkgs;
    unstable = unstableFor pkgs.stdenv.hostPlatform.system;
    packages = map (p: p.outPath) profile.home.home.packages;
  in
    lib.all (name: lib.any (source: builtins.elem source.${name}.outPath packages) [pkgs unstable]) [
      "bandwhich"
      "cdo"
      "dnstop"
      "eccodes"
      "gdal"
      "h5glance"
      "h5utils"
      "inetutils"
      "inxi"
      "ipcalc"
      "killall"
      "mtr"
      "net-tools"
      "netcat-gnu"
      "netcdf"
      "ntfs3g"
      "util-linux"
    ])
  [
    {
      home = linuxWorkstation;
      pkgs = flake.homeConfigurations.mimir2.pkgs;
    }
    {
      home = darwinWorkstation;
      pkgs = flake.darwinConfigurations.loki.pkgs;
    }
  ]; true;
  workstationAgentsAndJpegli = assert lib.all (home:
    lib.all (name: builtins.any (package: (package.pname or "") == name) home.home.packages) [
      "codex"
      "github-copilot-cli"
      "jpegli"
    ]) [
    linuxWorkstation
    darwinWorkstation
  ];
  assert builtins.length (lib.unique (map (p: p.outPath) (builtins.filter (p: (p.pname or "") == "github-copilot-cli") darwinWorkstation.home.packages))) == 1; true;
  nixPlatformConfig = assert lib.all (home: lib.hasInfix "/nix.linux.conf" home.home.file.".config/nix/nix.platform.conf".source.buildCommand) [wodan mimir2 linuxWorkstation];
  assert lib.all (home: lib.hasInfix "/nix.darwin.conf" home.home.file.".config/nix/nix.platform.conf".source.buildCommand) [loki darwinWorkstation]; true;
  locatePackages = assert lib.all (home: let
    packages = builtins.filter (p: (p.pname or "") == "plocate") home.home.packages;
  in
    builtins.length packages == 1 && !(builtins.any (p: (p.pname or "") == "mlocate") home.home.packages)) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg"]); true;
  userLocate = let
    homes =
      [mimir2 loki linuxWorkstation darwinWorkstation]
      ++ map (host: host.config) (builtins.attrValues flake.homeConfigurations)
      ++ lib.concatMap (host: builtins.attrValues (host.config.home-manager.users or {}))
      (builtins.attrValues flake.nixosConfigurations ++ builtins.attrValues flake.darwinConfigurations);
  in
    assert lib.all (home: lib.all (name: home.home.file ? ".local/bin/${name}") ["locate" "plocate" "updatedb"] && home.xdg.configFile ? "plocate/updatedb.conf") homes; true;
  linuxLocate = assert lib.all (host: !host.config.services.locate.enable) (builtins.attrValues flake.nixosConfigurations); assert mimir2.systemd.user.timers.plocate.Timer.Persistent; assert wodan.systemd.user.services.plocate.Service.Type == "oneshot"; true;
  macosLocate = let
    agent = loki.launchd.agents.plocate;
    package = builtins.head (builtins.filter (p: (p.pname or "") == "plocate") loki.home.packages);
  in
    assert package.src.rev == "4bfea2886010d1d4bcf63cac9b83753d1ab00cde";
    assert !(flake.darwinConfigurations.loki.config.launchd.daemons ? locate);
    assert agent.enable && agent.config.RunAtLoad && agent.config.ProcessType == "Background";
    assert agent.config.UserName == null && agent.config.GroupName == null;
    assert agent.config.StartCalendarInterval
    == [
      {
        Day = null;
        Hour = 3;
        Minute = 15;
        Month = null;
        Weekday = null;
      }
    ]; true;
  nixIndexInitialization = assert lib.all (home: home.home.activation ? nixIndex) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  macosTimeout = assert lib.all (home: toString home.home.file.".local/bin/timeout".source == "${(unstableFor "aarch64-darwin").coreutils}/bin/timeout" && lib.hasSuffix "-gtimeout" (toString home.home.file.".local/bin/gtimeout".source)) [loki darwinWorkstation]; assert !(mimir2.home.file ? ".local/bin/timeout"); true;
  linuxSpeech = assert lib.all (home: lib.all (package: builtins.any (p: (p.pname or "") == package) home.home.packages) ["espeak-ng" "piper-tts"]) ([mimir2] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  macosSpeech = assert lib.all (home: lib.all (name: builtins.any (p: (p.pname or "") == name) home.home.packages) ["espeak-ng" "piper-tts" "coreutils" "gnused"] && lib.all (path: builtins.hasAttr path home.home.file) [".local/bin/say" ".local/bin/say-piper-tts" ".config/say/espeak-ng-data" ".config/say/piper.sed" ".local/share/piper-voices/nl_NL-pim-medium.onnx" ".local/share/piper-voices/nl_NL-pim-medium.onnx.json"]) [loki darwinWorkstation]; true;
  physicalTools = assert lib.all (name: checkSources "x86_64-linux" flake.nixosConfigurations.${name}.config.home-manager.users.david (["hurl" "sqruff" "worktrunk"] ++ cliTools)) ["wodan" "donar" "frigg" "bragi"]; true;
  worktrunkSkills = assert lib.all (home: lib.all (client: home.home.file.".${client}/skills/worktrunk".source == home.home.file.".agents/skills/worktrunk".source) ["codex" "copilot" "config/opencode" "pi/agent"]) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  playwrightCli = assert builtins.elem stable.playwright-cli.outPath installed; assert lib.all (path: toString wodan.home.file.${path}.source == "${stable.playwright-cli}/share/skills/playwright-cli") [".agents/skills/playwright-cli" ".codex/skills/playwright-cli" ".copilot/skills/playwright-cli" ".config/opencode/skills/playwright-cli"]; assert lib.all (host: host.config.networking.hostName == "wodan" || !(builtins.any (p: (p.pname or "") == "playwright-cli") (host.config.home-manager.users.david.home.packages or []))) (builtins.attrValues flake.nixosConfigurations); true;
  browserMcp = assert lib.all (package: builtins.elem package.outPath installed) [stable.chrome-devtools-mcp (unstableFor "x86_64-linux").playwright-mcp]; true;
  workMcp = assert lib.all (home: lib.all (name: builtins.any (package: (package.pname or "") == name) home.home.packages) ["chrome-devtools-mcp" "mcp-nixos" "playwright-mcp"]) [mimir2 loki linuxWorkstation darwinWorkstation]; true;
  opencodeMcpLaunchers = assert lib.all (name: builtins.any (package: (package.name or "") == "opencode-mcp-${name}") wodan.home.packages) ["chrome-devtools" "nixos" "playwright"]; true;
  opencodeCli = assert lib.all (home: lib.hasInfix "/dotfiles/opencode-2.0.32/.config/opencode/cli.json" home.home.file.".config/opencode/cli.json".source.buildCommand) [wodan mimir2 loki linuxWorkstation darwinWorkstation]; true;
  dbhub = assert builtins.elem stable.dbhub.outPath installed; assert wodan.home.activation ? dbhubLocalDatabase; assert wodan.programs.pi.coding-agent.mcp.mcpServers.dbhub.args == ["--transport" "stdio" "--config" "${wodan.xdg.configHome}/dbhub/local.toml"]; assert lib.hasInfix "sqlite://${wodan.xdg.dataHome}/dbhub/local.sqlite" wodan.xdg.configFile."dbhub/local.toml".text; true;
  nixosMcp = assert lib.all (home: home.home.activation ? mcpClients) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
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
