{
  config,
  lib,
  stable,
  ...
}: let
  package = stable.callPackage ../../pkgs/qartez {};
in
  lib.mkIf (lib.elem stable.stdenv.hostPlatform.system package.meta.platforms) {
    home.packages = [
      package
    ];
    programs.pi.coding-agent.mcp.mcpServers.qartez = {
      command = "${config.home.homeDirectory}/.local/bin/qartez";
      description = "Indexed code navigation, source lookup and impact analysis";
    };
    home.file = {
      ".local/bin/qartez" = {
        source = "${package}/bin/qartez";
        force = true;
      };
      ".local/bin/qartez-guard" = {
        source = "${package}/bin/qartez-guard";
        force = true;
      };
      ".local/bin/qartez-setup" = {
        source = "${package}/bin/qartez-setup";
        force = true;
      };
    };
  }
