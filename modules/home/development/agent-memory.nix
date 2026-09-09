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
  python = stable.python3.withPackages (p: [p.tomlkit]);
  configureClients = stable.writeText "configure-agent-memory.py" ''
    import json
    import os
    from pathlib import Path
    import shutil
    import sys
    import tempfile
    import tomlkit

    home = Path(sys.argv[1])
    # Clients started outside a shell also need an absolute executable path.
    command = ${builtins.toJSON "${memory}/bin/agent-memory"}
    for relative, section, loads, dumps in [
        (".codex/config.toml", "mcp_servers", tomlkit.loads, tomlkit.dumps),
        (".claude.json", "mcpServers", json.loads, lambda value: json.dumps(value, indent=2) + "\n"),
    ]:
        path = (home / relative).resolve()
        original = path.read_text() if path.exists() else ""
        document = loads(original) if original else {}
        servers = document.setdefault(section, {})
        servers.pop("engram", None)
        servers.pop("engrim", None)
        servers["agent-memory"] = {"command": command, "args": ["mcp"]}
        updated = dumps(document)
        if updated == original:
            continue
        path.parent.mkdir(parents=True, exist_ok=True)
        backup = path.with_name(path.name + ".before-agent-memory")
        if path.exists() and not backup.exists():
            shutil.copy2(path, backup)
        fd, temporary = tempfile.mkstemp(dir=path.parent)
        try:
            with os.fdopen(fd, "w") as stream:
                stream.write(updated)
            os.replace(temporary, path)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)
  '';
in {
  options.nixcfg.agentMemory.provider = lib.mkOption {
    type = lib.types.enum ["engram" "engrim"];
    default = "engram";
    description = "Durable memory backend shared by coding clients. Both databases are retained when switching.";
  };

  config = {
    home.packages = [local.engram local.engrim local.ctx memory];
    xdg.configFile."agent-memory/provider".text = provider + "\n";

    home.activation.agentMemoryClients = lib.hm.dag.entryAfter ["writeBoundary"] ''
      $DRY_RUN_CMD ${python}/bin/python ${configureClients} ${lib.escapeShellArg config.home.homeDirectory}
    '';

    systemd.user.services.ctx-history = {
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
