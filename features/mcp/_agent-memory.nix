{
  config,
  lib,
  local,
  stable,
  ...
}: let
  provider = config.nixcfg.agentMemory.provider;
  memory = stable.writeShellScriptBin "agent-memory" ''
    exec ${lib.getExe local.${provider}} "$@"
  '';
in {
  options.nixcfg.agentMemory.provider = lib.mkOption {
    type = lib.types.enum ["engram" "engrim"];
    default = "engram";
    description = "Durable memory backend shared by coding clients. Both databases are retained when switching.";
  };

  config = {
    home = {
      packages =
        (
          if stable.stdenv.hostPlatform.isLinux
          then [local.engram local.engrim local.ctx]
          else [local.${provider}]
        )
        ++ [memory];
      file.".local/bin/agent-memory".source = "${memory}/bin/agent-memory";
    };
    xdg.configFile."agent-memory/provider".text = provider + "\n";

    programs.pi.coding-agent.mcp.mcpServers.agent-memory = {
      command = "${config.home.homeDirectory}/.local/bin/agent-memory";
      args = ["mcp"];
      description = "Shared durable project memory";
    };

    systemd.user.services.ctx-history = lib.mkIf stable.stdenv.hostPlatform.isLinux {
      Unit.Description = "Index local coding-agent history for CTX";
      Service = {
        Type = "simple";
        ExecStartPre = "${local.ctx}/bin/ctx setup --no-daemon --quiet";
        ExecStart = "${local.ctx}/bin/ctx daemon run";
        TimeoutStartSec = "10min";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = ["CTX_UPGRADE_AUTO=off"];
      };
      Install.WantedBy = ["default.target"];
    };
  };
}
