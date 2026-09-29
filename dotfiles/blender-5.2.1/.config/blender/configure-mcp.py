"""Apply the declarative MCP preferences inside Blender without saving a scene."""

from pathlib import Path

import addon_utils
import bpy
import tomllib

settings = tomllib.loads((Path.home() / ".config/blender/mcp.toml").read_text())
preferences = bpy.context.preferences
module = "bl_ext.user_default.mcp"
# Upstream requires online access even for its loopback socket.
preferences.system.use_online_access = True
addon_utils.enable(module, default_set=True, persistent=True)
addon_preferences = preferences.addons[module].preferences
for name in ("host", "port", "use_autostart"):
    setattr(addon_preferences, name, settings[name])
bpy.ops.wm.save_userpref()
print("Blender Lab MCP preferences saved", dict(settings))
