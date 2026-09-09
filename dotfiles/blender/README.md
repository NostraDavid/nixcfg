# Blender Lab MCP

`modules/home/media/blender-mcp.nix` installs the official Blender Lab server
and extension from the same Git revision. Nix supplies Python and dependencies;
no uv downloads or system Python changes are needed at startup.

`.config/blender/mcp.toml` defines the loopback endpoint and auto-start
preference. Home Manager merges the Codex server into `~/.codex/config.toml`,
preserving other settings and backing up the original as
`config.toml.before-blender-mcp`.

After changing Blender preferences here, or installing for a new Blender minor
version, close Blender and apply them without modifying a scene:

```sh
blender --background --online-mode --python-exit-code 1 \
  --python ~/.config/blender/configure-mcp.py
```

Open Blender normally afterwards. The upstream extension requires Blender's
online-access preference even for its local socket; the script enables it. The
listener binds to `127.0.0.1:9876` and starts automatically. Restart Codex
Desktop after initially adding the server to load its tools.

Upstream: <https://projects.blender.org/lab/blender_mcp>
