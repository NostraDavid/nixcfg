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
  ctxHistorySetup = stable.writeShellScript "ctx-history-setup" ''
    set -e
    ompSessions=${lib.escapeShellArg "${config.home.homeDirectory}/.omp/agent/sessions"}
    if [ -d "$ompSessions" ]; then
      ${local.ctx}/bin/ctx sources add omp --provider pi --root "$ompSessions" --quiet
    fi
    exec ${local.ctx}/bin/ctx setup --no-daemon --quiet
  '';
in {
  options.nixcfg.agentMemory.provider = lib.mkOption {
    type = lib.types.enum [
      "engram"
      "engrim"
    ];
    default = "engram";
    description = "Durable memory backend shared by coding clients. Both databases are retained when switching.";
  };

  config = {
    home = {
      packages =
        (
          if stable.stdenv.hostPlatform.isLinux
          then [
            local.engram
            local.engrim
            local.ctx
          ]
          else [
            local.${provider}
            local.ctx
          ]
        )
        ++ [
          memory
        ];
      file.".local/bin/agent-memory".source = "${memory}/bin/agent-memory";
    };
    xdg.configFile."agent-memory/provider".text = provider + "\n";

    nixcfg.mcp.servers.agent-memory = {
      command = "${config.home.homeDirectory}/.local/bin/agent-memory";
      args = [
        "mcp"
      ];
      description = "Shared durable project memory";
    };

    systemd.user.services.ctx-history = lib.mkIf stable.stdenv.hostPlatform.isLinux {
      Unit.Description = "Index local coding-agent history for CTX";
      Service = {
        Type = "simple";
        ExecStartPre = "${ctxHistorySetup}";
        ExecStart = "${local.ctx}/bin/ctx daemon run";
        TimeoutStartSec = "10min";
        Restart = "on-failure";
        RestartSec = 5;
        Environment = [
          "CTX_UPGRADE_AUTO=off"
        ];
      };
      Install.WantedBy = [
        "default.target"
      ];
    };
  };
}
