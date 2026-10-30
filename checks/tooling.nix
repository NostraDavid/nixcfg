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
  in
    assert lib.all (name:
      lib.assertMsg
      (builtins.any (p: (p.pname or "") == pkgs.${name}.pname && p.outPath == pkgs.${name}.outPath) home.home.packages)
      "Expected unstable.${name} in ${system} tooling profile")
    names; true;
  cliTools = [
    "actionlint"
    "flameshot"
    "fast-resume"
    "herdr"
    "just"
    "just-lsp"
    "lnav"
    "lazyjournal"
    "less"
    "mise"
    "more"
    "most"
    "nix-index"
    "nix-tree"
    "nvd"
    "posting"
    "shfmt"
    "ov"
    "watchexec"
    "yazi"
    "zellij"
  ];
  core =
    [
      "ast-grep"
      "bat"
      "cloc"
      "fd"
      "fzf"
      "git-lfs"
      "git"
      "hurl"
      "lsd"
      "mergiraf"
      "sqruff"
      "starship"
      "superfile"
      "tmux"
      "tree"
      "tuios"
      "tree-sitter"
      "universal-ctags"
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
  herdrGui = assert lib.all (home:
    lib.all (name: builtins.any (p: (p.pname or "") == name) home.home.packages) ["herdr-gpui" "herdr-app" "herdr-core"])
  ([mimir2 loki] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  pagerTools = assert lib.all (home:
    builtins.any (p: (p.pname or "") == "batman") home.home.packages) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  portableToolsNixos = assert lib.all (host: lib.all (name: builtins.elem (unstableFor "x86_64-linux").${name}.outPath (map (p: p.outPath) host.config.environment.systemPackages)) ["superfile" "tuios"]) (builtins.attrValues flake.nixosConfigurations); true;
  desktopIdeLauncher = wodan.home.file.".local/bin/ide-desktop".source.text;
  commandPaths = let
    workLoki =
      (flake.lib.mkLoki {
        username = "work-user";
        homeDirectory = "/Users/work home";
      }).config.home-manager.users."work-user";
    homes = [mimir2 loki linuxWorkstation darwinWorkstation workLoki] ++ lib.concatMap (host: builtins.attrValues (host.config.home-manager.users or {})) (builtins.attrValues flake.nixosConfigurations);
    settings = builtins.fromJSON (builtins.readFile ../dotfiles/vscode-1.106.2/.config/Code/User/settings.json);
    terminalFiles = [".config/alacritty/alacritty.toml" ".config/bat/config" ".config/starship.toml" ".config/zellij/config.kdl"];
    direct = home: name: let
      script = home.home.file.${name}.source.buildCommand or "";
    in
      lib.hasInfix "ln -s" script && lib.hasInfix "/dotfiles/" script;
  in
    assert lib.all (home:
      !(home.home.activation ? vscodeExtensions)
      && lib.all (step:
        lib.all (command: !(lib.hasInfix command (step.data or ""))) ["--install-extension" "--uninstall-extension"])
      (builtins.attrValues home.home.activation))
    homes;
    assert lib.all (
      home:
        !(home.home.file ? ".config/git/common.conf")
        || home.home.file ? ".local/bin/delta"
    )
    homes;
    assert mimir2.home.file.".local/bin/delta".source == lib.getExe (unstableFor "x86_64-linux").delta;
    assert loki.home.file.".local/bin/delta".source == lib.getExe (unstableFor "aarch64-darwin").delta;
    assert settings."dprint.path" == "~/.local/bin/dprint" && settings."git.path" == "git" && settings."shfmt.executablePath" == "shfmt";
    assert !(settings ? "shellformat.path") && settings."todo-tree.ripgrep.ripgrep" == "~/.local/bin/rg";
    assert direct wodan ".config/Code/User/settings.json";
    assert lib.all (home:
      !(home.home.file ? ".config/Code/User/settings.json")
      && !(home.home.file ? "Library/Application Support/Code/User/settings.json")) [mimir2 loki linuxWorkstation darwinWorkstation workLoki];
    assert lib.all (home: let
      activation = home.home.activation.linkPackageCommands;
    in
      lib.all (name: home.home.file ? ${name} -> direct home name) terminalFiles
      && lib.all (name: direct home name) [".pi/agent/settings.json" ".pi/agent/mcp.json"]
      && home.programs.pi.coding-agent.settings == {}
      && home.programs.pi.coding-agent.mcp == {}
      && (!(home.home.file ? ".config/zellij/config.kdl") || (home.home.file ? ".config/zellij/layouts/default.kdl" && direct home ".config/zellij/layouts/default.kdl"))
      && lib.hasInfix (lib.escapeShellArg home.home.profileDirectory) activation.data
      && lib.all (step: builtins.elem step activation.after) ["installPackages" "linkGeneration"])
    homes; true;
  asdSte100WorkPackages = let
    pkgs = flake.darwinConfigurations.loki.pkgs;
    module = (import ../features/common-tooling/default.nix {}).den.aspects.common-tooling.homeManager;
    home = module {
      config = {};
      repoRoot = "/unused";
      inherit lib;
      stable = pkgs;
      unstable = unstableFor "aarch64-darwin";
      local = builtins.removeAttrs flake.darwinConfigurations.loki.config.home-manager.extraSpecialArgs.local ["asd-ste100-skill"];
    };
  in
    assert home.home.file.".config/opencode/skills/asd-ste100".source == loki.home.file.".config/opencode/skills/asd-ste100".source; true;
  asdSte100 = let
    homes = [mimir2 loki linuxWorkstation darwinWorkstation] ++ lib.concatMap (host: builtins.attrValues (host.config.home-manager.users or {})) (builtins.attrValues flake.nixosConfigurations);
    clients = ["agents" "claude" "codex" "config/opencode" "copilot" "pi/agent"];
  in
    assert lib.all (home: lib.all (client: home.home.file.".${client}/skills/asd-ste100".source == home.home.file.".agents/skills/asd-ste100".source) clients) homes; true;
  pandacode = assert lib.all (home: builtins.any (p: (p.pname or "") == "pandacode" && p.outPath == flake.packages.${p.system}.pandacode.outPath) home.home.packages) [wodan mimir2 loki]; true;
  fleetGitLfs = let
    systems = builtins.attrValues flake.nixosConfigurations;
    homes = [mimir2 loki linuxWorkstation darwinWorkstation];
  in
    assert lib.all (host: host.config.programs.git.enable && host.config.programs.git.lfs.enable && builtins.elem host.config.programs.git.lfs.package.outPath (map (p: p.outPath) host.config.environment.systemPackages) && lib.hasInfix "git-lfs filter-process" host.config.environment.etc.gitconfig.text) systems;
    assert lib.all (home: builtins.any (p: (p.pname or "") == "git-lfs") home.home.packages && lib.hasInfix "/dotfiles/git-2.49.0/.config/git/common.conf" home.home.file.".config/git/common.conf".source.buildCommand) homes; true;
  forgejoLfs = let
    forgejo = flake.nixosConfigurations.forgejo.config;
    secretFile = "/srv/forgejo/forgejo/custom/conf/lfs_jwt_secret";
    secretService = forgejo.systemd.services.forgejo-secrets.script;
    server = forgejo.services.forgejo.settings.server;
  in
    assert server.LFS_START_SERVER;
    assert server.LFS_JWT_SECRET_URI == "file:${secretFile}";
    assert lib.hasInfix "if [ ! -s ${secretFile} ]" secretService;
    assert lib.hasInfix "generate secret LFS_JWT_SECRET > ${secretFile}" secretService; true;
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
  plasmaCrashLauncher = assert lib.all (name: let
    home = flake.nixosConfigurations.${name}.config.home-manager.users.david;
    launcher = home.systemd.user.services."drkonqi-coredump-launcher@";
  in
    launcher.Unit.X-SwitchMethod
    == "keep-old"
    && launcher.Service.Restart == "no"
    && launcher.Service.LimitCORE == 0
    && lib.elem "drkonqi-coredump-launcher" (lib.splitString "," home.programs.plasma.session.sessionRestore.excludeApplications)) ["wodan" "donar" "frigg"]; true;
  macosTimeout = assert lib.all (home: toString home.home.file.".local/bin/timeout".source == "${(unstableFor "aarch64-darwin").coreutils}/bin/timeout" && lib.hasSuffix "-gtimeout" (toString home.home.file.".local/bin/gtimeout".source)) [loki darwinWorkstation]; assert !(mimir2.home.file ? ".local/bin/timeout"); true;
  linuxSpeech = assert lib.all (home: lib.all (package: builtins.any (p: (p.pname or "") == package) home.home.packages) ["espeak-ng" "piper-tts"]) ([mimir2] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  macosSpeech = assert lib.all (home: lib.all (name: builtins.any (p: (p.pname or "") == name) home.home.packages) ["espeak-ng" "piper-tts" "coreutils" "gnused"] && lib.all (path: builtins.hasAttr path home.home.file) [".local/bin/say" ".local/bin/say-piper-tts" ".config/say/espeak-ng-data" ".config/say/piper.sed" ".local/share/piper-voices/nl_NL-pim-medium.onnx" ".local/share/piper-voices/nl_NL-pim-medium.onnx.json"]) [loki darwinWorkstation]; true;
  physicalTools = assert lib.all (name: checkSources "x86_64-linux" flake.nixosConfigurations.${name}.config.home-manager.users.david (["hurl" "sqruff" "worktrunk"] ++ cliTools)) ["wodan" "donar" "frigg" "bragi"]; true;
  worktrunkSkills = assert lib.all (home: lib.all (client: home.home.file.".${client}/skills/worktrunk".source == home.home.file.".agents/skills/worktrunk".source) ["codex" "copilot" "config/opencode" "pi/agent"]) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  worktrunkIntegrations = assert lib.all (home:
    home.home.file ? ".config/worktrunk/config.toml"
    && !home.home.file.".config/worktrunk/config.toml".force
    && home.home.file ? ".config/opencode/plugins/worktrunk.ts"
    && home.home.file ? "plugins/worktrunk"
    && home.home.activation ? worktrunkCodex)
  ([mimir2 loki] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  playwrightCli = assert builtins.elem stable.playwright-cli.outPath installed; assert lib.all (path: toString wodan.home.file.${path}.source == "${stable.playwright-cli}/share/skills/playwright-cli") [".agents/skills/playwright-cli" ".codex/skills/playwright-cli" ".copilot/skills/playwright-cli" ".config/opencode/skills/playwright-cli"]; assert lib.all (host: host.config.networking.hostName == "wodan" || !(builtins.any (p: (p.pname or "") == "playwright-cli") (host.config.home-manager.users.david.home.packages or []))) (builtins.attrValues flake.nixosConfigurations); true;
  browserMcp = assert lib.all (package: builtins.elem package.outPath installed) [stable.chrome-devtools-mcp (unstableFor "x86_64-linux").playwright-mcp]; true;
  workMcp = assert lib.all (home: lib.all (name: builtins.any (package: (package.pname or "") == name) home.home.packages) ["chrome-devtools-mcp" "mcp-nixos" "playwright-mcp"]) [mimir2 loki linuxWorkstation darwinWorkstation]; true;
  opencodeMcpLaunchers = assert lib.all (name: wodan.home.file.".local/bin/opencode-mcp-${name}".source == wodan.home.file.".local/bin/mcp-${name}".source) ["chrome-devtools" "nixos" "playwright"]; true;
  opencodeCli = assert lib.all (home: lib.hasInfix "/dotfiles/opencode-2.0.32/.config/opencode/cli.json" home.home.file.".config/opencode/cli.json".source.buildCommand) [wodan mimir2 loki linuxWorkstation darwinWorkstation]; true;
  dbhub = assert builtins.elem stable.dbhub.outPath installed; assert wodan.home.activation ? dbhubLocalDatabase; assert wodan.nixcfg.mcp.servers.dbhub.args == ["--transport" "stdio" "--config" "${wodan.xdg.configHome}/dbhub/local.toml"]; assert lib.hasInfix "sqlite://${wodan.xdg.dataHome}/dbhub/local.sqlite" wodan.xdg.configFile."dbhub/local.toml".text; true;
  nixosMcp = assert lib.all (home: lib.all (name: home.home.file ? ".local/bin/${name}") ["codex" "opencode"]) ([mimir2 loki linuxWorkstation darwinWorkstation] ++ map (name: flake.nixosConfigurations.${name}.config.home-manager.users.david) ["wodan" "donar" "frigg" "bragi"]); true;
  opencode = assert lib.all (host: builtins.elem host.pkgs.opencode-v2.outPath (map (p: p.outPath) host.config.environment.systemPackages)) (builtins.attrValues flake.nixosConfigurations); assert builtins.elem stable.opencode-v2.outPath (map (p: p.outPath) mimir2.home.packages); assert builtins.any (p: (p.pname or "") == "opencode-v2" && lib.hasPrefix "2." p.version) loki.home.packages; assert builtins.elem stable.opencode-v2-desktop.outPath installed; assert !(builtins.any (p: lib.hasPrefix "opencode" (p.pname or "") && lib.hasPrefix "1." (p.version or "")) (wodan.home.packages ++ linuxWorkstation.home.packages ++ darwinWorkstation.home.packages)); true;
  cmux = assert lib.all (host: builtins.elem host.pkgs.cmux-tui.outPath (map (p: p.outPath) host.config.environment.systemPackages)) (builtins.attrValues flake.nixosConfigurations); assert builtins.elem stable.cmux-tui.outPath (map (p: p.outPath) mimir2.home.packages); assert builtins.elem (unstableFor "aarch64-darwin").cmux.outPath (map (p: p.outPath) loki.home.packages); assert builtins.any (p: (p.pname or "") == "cmux-tui" && p.system == "aarch64-darwin" && (p.meta.priority or 5) < ((unstableFor "aarch64-darwin").cmux.meta.priority or 5)) loki.home.packages; true;
  wodan = checkSources "x86_64-linux" wodan (core ++ builtins.filter (name: name != "opentofu") workstation ++ ["lua-language-server"]);
  codeNavigation = let
    profiles =
      map (name: {
        home = flake.nixosConfigurations.${name}.config.home-manager.users.david;
        system = "x86_64-linux";
      }) ["wodan" "donar" "frigg" "bragi"]
      ++ map (home: {
        inherit home;
        system = "x86_64-linux";
      }) [mimir2 linuxWorkstation]
      ++ map (home: {
        inherit home;
        system = "aarch64-darwin";
      }) [loki darwinWorkstation];
  in
    assert lib.all ({
      home,
      system,
    }: let
      pkgs = unstableFor system;
      native = (import ../nix/packages.nix {inherit (flake) inputs;}).pkgsFor system;
    in
      lib.all (package:
        lib.any (installed: (installed.pname or "") == package.pname && installed.outPath == package.outPath)
        home.home.packages) ([
          pkgs.ast-grep
          pkgs.cloc
          pkgs.fd
          pkgs.fzf
          pkgs.python3Packages.lizard
          pkgs.ripgrep
          pkgs.sd
          pkgs.tree-sitter
          pkgs.universal-ctags
          native.probe
        ]
        ++ lib.optionals (system == "x86_64-linux") [native.semble])
      && (system == "x86_64-linux" || !(builtins.any (p: (p.pname or "") == "semble") home.home.packages)))
    profiles; true;
  editorTooling = assert checkSources "x86_64-linux" wodan ["bash-language-server" "lua-language-server" "marksman" "nixd" "sqls" "taplo" "vscode-langservers-extracted" "yaml-language-server" "zuban"];
  assert checkSources "x86_64-linux" linuxWorkstation ["basedpyright" "nixd" "ruby-lsp" "sqls"];
  assert checkSources "aarch64-darwin" darwinWorkstation ["basedpyright" "nixd" "ruby-lsp" "sqls"]; true;
  debian = checkSources "x86_64-linux" mimir2 core;
  macos = checkSources "aarch64-darwin" loki core;
  debianWorkstation = checkSources "x86_64-linux" linuxWorkstation (core ++ workstation);
  macosWorkstation = checkSources "aarch64-darwin" darwinWorkstation (core ++ workstation);
  helmCompatibility = assert builtins.elem stable.kubernetes-helm.outPath (map (p: p.outPath) linuxWorkstation.home.packages); true;
  direnv = assert wodan.programs.direnv.package.outPath == (unstableFor "x86_64-linux").direnv.outPath; assert wodan.programs.direnv.nix-direnv.package.outPath == (unstableFor "x86_64-linux").nix-direnv.outPath; true;
  compatibilityPins = assert lib.all (package: builtins.elem package.outPath installed) [stable.nodejs_24 stable.gcc stable.gcc-unwrapped stable.postgresql stable.kubernetes-helm]; true;
}
