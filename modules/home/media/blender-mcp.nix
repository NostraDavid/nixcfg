{
  config,
  lib,
  local,
  stable,
  unstable,
  ...
}: let
  python = stable.python3.withPackages (p: [p.tomlkit]);
  blenderVersion = lib.versions.majorMinor unstable.blender.version;
  dotfiles = ../../../dotfiles/blender/.config/blender;
in {
  home = {
    packages = [local.blender-mcp];
    file = {
      ".config/blender/mcp.toml".source = dotfiles + /mcp.toml;
      ".config/blender/configure-mcp.py".source = dotfiles + /configure-mcp.py;
      ".config/blender/${blenderVersion}/extensions/user_default/mcp".source = "${local.blender-mcp}/share/blender-mcp/mcp";
    };

    # Merge only the Blender entry: Codex owns the rest of this mutable file.
    activation.blenderMcpClient = lib.hm.dag.entryAfter ["headroomClients" "linkGeneration"] ''
      $DRY_RUN_CMD ${python}/bin/python - <<'PY'
      import os
      from pathlib import Path
      import shutil
      import tempfile
      import tomlkit

      home = Path(${builtins.toJSON config.home.homeDirectory})
      settings = tomlkit.loads((home / ".config/blender/mcp.toml").read_text())
      path = home / ".codex/config.toml"
      original = path.read_text() if path.exists() else ""
      document = tomlkit.loads(original)
      servers = document.setdefault("mcp_servers", {})
      servers.pop("blender_mcp", None)
      servers["blender"] = {
          "command": "${local.blender-mcp}/bin/blender-mcp",
          "args": ["--transport", "stdio"],
          "startup_timeout_sec": settings["startup_timeout_sec"],
          "env": {"BLENDER_MCP_HOST": settings["host"], "BLENDER_MCP_PORT": str(settings["port"])},
      }
      updated = tomlkit.dumps(document)
      if updated != original:
          path.parent.mkdir(parents=True, exist_ok=True)
          backup = path.with_name("config.toml.before-blender-mcp")
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
      PY
    '';
  };
}
