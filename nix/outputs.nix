{
  inputs,
  self,
  ...
}: let
  packageSets = import ./packages.nix {inherit inputs;};
  inherit (packageSets) pkgsFor unstableFor mkLocal;
  inherit (self.lib) mkMimir2;
in {
  systems = [
    "x86_64-linux"
  ];
  flake = {
    overlays.default = packageSets.overlay-local;
    packages.aarch64-darwin = {
      inherit (pkgsFor "aarch64-darwin") asd-ste100-skill pandacode uv video-explainer;
    };
  };
  perSystem = {system, ...}: let
    stable = pkgsFor system;
    unstable = unstableFor system;
  in {
    _module.args.pkgs = stable;

    legacyPackages = stable // {inherit unstable;};

    checks = {
      certificate-trust = import ../checks/certificate-trust.nix {
        pkgs = stable;
        inherit unstable;
        flake = self;
      };
      architecture = let
        result = import ../checks/architecture.nix {flake = self;};
      in
        assert builtins.all (value: value) (builtins.attrValues result);
          stable.writeText "nixcfg-architecture.json" (builtins.toJSON result);

      agent-instructions = import ../checks/agent-instructions.nix {
        pkgs = stable;
        homeFiles = self.nixosConfigurations.wodan.config.home-manager.users.david.home.file;
        workHomeFiles =
          (mkMimir2 {
            extraHomeModules = [
              ({lib, ...}: {
                home.file."AGENTS.md".source = lib.mkForce (stable.writeText "test-agent-instructions-override.md" ''
                  Read and follow ~/.agents/instructions/shared.md before starting work.
                  Work-specific instructions take precedence when they conflict.
                '');
              })
            ];
          }).config.home.file;
      };

      video-explainer =
        stable.runCommand "video-explainer-check" {
          nativeBuildInputs = [
            stable.video-explainer
            stable.ffmpeg
          ];
        } ''
          export HOME="$TMPDIR/home"
          mkdir -p "$HOME"
          video-explainer check
          video-explainer unit-test
          video-explainer render ${../checks/fixtures/video-explainer}/manifest.json --output "$TMPDIR/render"
          mkdir -p "$out"
          cp -R "$TMPDIR/render/." "$out/"
        '';
    };

    packages =
      stable.lib.filterAttrs (_: package: stable.lib.meta.availableOn stable.stdenv.hostPlatform package) (mkLocal stable)
      // {
        win11-icon-theme =
          stable.win11-icon-theme or (stable.callPackage (builtins.path {
            path = ../pkgs/win11-icon-theme;
            name = "win11-icon-theme";
          }) {});
        win11os-kde =
          stable.win11os-kde or (stable.callPackage (builtins.path {
            path = ../pkgs/win11os-kde;
            name = "win11os-kde";
          }) {});
      };

    devShells.default = stable.mkShell {
      # Tools needed before the first Home Manager activation.
      packages = [
        stable.git
        stable.git-lfs
        stable.just
      ];

      shellHook = ''
        export NIX_CONFIG="experimental-features = nix-command flakes
        ''${NIX_CONFIG:-}"
      '';
    };
  };
}
