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
  core = ["git" "git-lfs" "just" "ast-grep" "mergiraf" "fd" "fzf" "bat" "lsd" "starship" "tmux" "tree"];
  workstation = ["ruff" "prek" "dprint" "shellcheck" "shfmt" "nixd" "pyrefly" "markdownlint-cli" "sbomnix" "grype" "opentofu" "sqlfluff" "jq"];
  stable = flake.nixosConfigurations.wodan.pkgs;
  installed = map (p: p.outPath) wodan.home.packages;
in {
  wodan = checkSources "x86_64-linux" wodan (core ++ builtins.filter (name: name != "opentofu") workstation ++ ["lua-language-server" "sqruff"]);
  debian = checkSources "x86_64-linux" mimir2 core;
  macos = checkSources "aarch64-darwin" loki core;
  debianWorkstation = checkSources "x86_64-linux" linuxWorkstation (core ++ workstation);
  macosWorkstation = checkSources "aarch64-darwin" darwinWorkstation (core ++ workstation);
  helmCompatibility = assert builtins.elem stable.kubernetes-helm.outPath (map (p: p.outPath) linuxWorkstation.home.packages); true;
  direnv = assert wodan.programs.direnv.package.outPath == (unstableFor "x86_64-linux").direnv.outPath; assert wodan.programs.direnv.nix-direnv.package.outPath == (unstableFor "x86_64-linux").nix-direnv.outPath; true;
  compatibilityPins = assert lib.all (package: builtins.elem package.outPath installed) [stable.nodejs_24 stable.gcc stable.gcc-unwrapped stable.openjdk25 stable.postgresql stable.kubernetes-helm]; true;
}
