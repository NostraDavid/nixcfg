{
  inputs,
  packageSets,
  den,
}: let
  inherit (inputs.nixpkgs) lib;
  inherit (packageSets) pkgsFor unstableFor mkLocal overlays overlay-ca-security nixpkgsConfig;
  selected = entity: map (aspect: aspect.name) entity.hasAspect.allAspects;
  guard = class: entity:
    import ../policy/module.nix {
      root = ../.;
      inherit class den;
      selected = selected entity;
      required = lib.optionals (class == "homeManager") [
        "annotation"
        "mcp"
      ];
    };
in {
  homeManagerBootstrap = {
    inputs,
    hostname,
    main-user,
    repoRoot,
    stable,
    unstable,
    local,
    ...
  }: {
    imports = [
      inputs.home-manager.nixosModules.home-manager
    ];
    home-manager = {
      backupFileExtension = "hm.bak";
      useGlobalPkgs = true;
      useUserPackages = true;
      extraSpecialArgs = {inherit inputs hostname repoRoot stable unstable local;};
      users.${main-user} = {
        imports = [
          inputs.codex-desktop-linux.homeManagerModules.default
          inputs.plasma-manager.homeModules.plasma-manager
        ];
        home = {
          username = main-user;
          homeDirectory = "/home/${main-user}";
          stateVersion = "25.05";
        };
        programs.home-manager.enable = true;
      };
    };
  };
  nixos = {
    hostname,
    repoSubdir ? "dev/NostraDavid/nixcfg/trunk",
    extraModules ? [],
    homeManager ? false,
  }: {modules, ...}: let
    system = "x86_64-linux";
    main-user = "david";
    repoRoot = "/home/${main-user}/${repoSubdir}";
    unstable = unstableFor system;
    entity = den.hosts.${system}.${hostname};
  in
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      specialArgs = {inherit inputs hostname main-user repoRoot unstable;};
      modules =
        modules
        ++ [
          (guard "nixos" entity)
          ({pkgs, ...}: {
            nixpkgs = {
              inherit overlays;
              config = nixpkgsConfig;
            };
            _module.args = {
              stable = pkgs;
              local = mkLocal pkgs;
            };
          })
        ]
        ++ lib.optional homeManager ({pkgs, ...}: {
          imports = [
            inputs.home-manager.nixosModules.home-manager
          ];
          home-manager = {
            backupFileExtension = "hm.bak";
            useGlobalPkgs = true;
            useUserPackages = true;
            extraSpecialArgs = {
              inherit inputs hostname main-user repoRoot unstable;
              stable = pkgs;
              local = mkLocal pkgs;
            };
            sharedModules = [
              (guard "homeManager" entity)
            ];
          };
        })
        ++ extraModules;
    };
  darwin = {
    username ? "david",
    homeDirectory ? "/Users/${username}",
    hostname ? "loki",
    extraDarwinModules ? [],
    extraHomeModules ? [],
  }: {modules, ...}: let
    system = "aarch64-darwin";
    unstable = unstableFor system;
    entity = den.hosts.${system}.loki;
  in
    inputs.nix-darwin.lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit inputs hostname unstable;
        main-user = username;
        repoRoot = "${homeDirectory}/nixcfg";
      };
      modules =
        modules
        ++ [
          inputs.nix-homebrew.darwinModules.nix-homebrew
          (guard "darwin" entity)
          ({pkgs, ...}: {
            _module.args = {
              stable = pkgs;
              local = mkLocal (pkgsFor system);
            };
            nixpkgs = {
              config = nixpkgsConfig;
              overlays = [
                overlay-ca-security
                (_final: _prev: {inherit (pkgsFor system) bashInteractive;})
              ];
            };
            home-manager = {
              backupFileExtension = "hm.bak";
              useGlobalPkgs = true;
              useUserPackages = true;
              extraSpecialArgs = {
                inherit inputs hostname unstable;
                repoRoot = "${homeDirectory}/nixcfg";
                stable = pkgs;
                local = mkLocal (pkgsFor system);
              };
              sharedModules = [
                (guard "homeManager" entity)
              ];
              users.${username}.imports = extraHomeModules;
            };
          })
        ]
        ++ extraDarwinModules;
    };
  home = {extraHomeModules ? []}: {
    pkgs,
    modules,
    ...
  }: let
    entity = den.homes.x86_64-linux.mimir2;
  in
    inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules =
        modules
        ++ [
          (guard "homeManager" entity)
        ]
        ++ extraHomeModules;
      extraSpecialArgs = {
        inherit inputs;
        hostname = "mimir2";
        repoRoot = "/home/david/nixcfg";
        stable = pkgs;
        unstable = unstableFor "x86_64-linux";
        local = mkLocal pkgs;
      };
    };
}
