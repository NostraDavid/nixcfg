import json
import os
import sys
import tempfile
from pathlib import Path

path = Path(sys.argv[1]) / ".agents/plugins/marketplace.json"
if path.is_symlink():
    raise SystemExit(f"Cannot replace symlinked marketplace: {path}")
document = (
    json.loads(path.read_text())
    if path.exists()
    else {"name": "personal", "plugins": []}
)
if (
    not isinstance(document, dict)
    or document.get("name") != "personal"
    or not isinstance(document.get("plugins"), list)
):
    raise SystemExit(f"Cannot update personal marketplace: {path}")
plugins = document["plugins"]
entry = {
    "name": "worktrunk",
    "source": {"source": "local", "path": "./plugins/worktrunk"},
    "policy": {"installation": "AVAILABLE"},
    "category": "Productivity",
}
updated = [
    plugin
    for plugin in plugins
    if not (isinstance(plugin, dict) and plugin.get("name") == "worktrunk")
]
updated.append(entry)
if updated != plugins:
    document["plugins"] = updated
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent)
    temporary_path = Path(temporary)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(document, stream, ensure_ascii=False, indent=2)
            stream.write("\n")
        temporary_path.replace(path)
    finally:
        temporary_path.unlink(missing_ok=True)
