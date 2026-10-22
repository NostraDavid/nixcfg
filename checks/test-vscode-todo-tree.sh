#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
vsix=$(nix build --impure --file "$root/checks/vscode-todo-tree.nix" vsix --no-link --print-out-paths)
node=$(nix build --impure --file "$root/checks/vscode-todo-tree.nix" node --no-link --print-out-paths)
python3 - "$vsix" "$node/bin/node" <<'PY'
import getpass
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile
from zipfile import ZipFile

vsix, node = map(Path, sys.argv[1:])
with ZipFile(vsix) as archive:
    manifest = json.loads(archive.read("extension/package.json"))
    bundle = archive.read("extension/dist/extension.js").decode()
assert manifest["publisher"].lower() == "gruntfuggly" and manifest["name"] == "todo-tree"
resolver = re.search(r'function t\(e\)\{if\(typeof e!=="string".*?void 0\}', bundle).group()
with tempfile.TemporaryDirectory(prefix="todo-tree-") as directory:
    tmp = Path(directory)
    home = tmp / "user $& home"
    rg = home / ".local/bin/rg"
    rg.parent.mkdir(parents=True)
    rg.touch()
    env = {key: value for key, value in os.environ.items() if not key.startswith("VSCODE_")}
    env.update(HOME=str(home), XDG_CONFIG_HOME=str(tmp / "config"), XDG_DATA_HOME=str(tmp / "data"), XDG_CACHE_HOME=str(tmp / "cache"))
    env.pop("ELECTRON_RUN_AS_NODE", None)
    program = '''
const assert = require("node:assert/strict");
const fs = require("node:fs");
const resolve = new Function("i", "require", "return (" + fs.readFileSync(0, "utf8") + ")")(fs, require);
const expected = require("node:path").join(require("node:os").homedir(), ".local/bin/rg");
assert.equal(resolve("~/.local/bin/rg"), expected);
assert.equal(resolve(expected), expected);
assert.equal(resolve("~/missing"), undefined);
assert.equal(resolve(undefined), undefined);
'''
    subprocess.run([node, "-e", program], input=resolver, text=True, env=env, check=True)
    candidates = [
        Path("/etc/profiles/per-user") / getpass.getuser() / "bin/code",
        Path.home() / ".nix-profile/bin/code",
        Path.home() / ".local/state/nix/profile/bin/code",
        Path.home() / "Applications/Visual Studio Code.app/Contents/Resources/app/bin/code",
        Path("/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"),
        Path("/run/current-system/sw/bin/code"),
        Path("/usr/bin/code"),
        Path("/usr/local/bin/code"),
    ]
    code = next((path for path in candidates if path.is_file() and os.access(path, os.X_OK)), None)
    if code is not None:
        subprocess.run([code, "--user-data-dir", str(tmp / "vscode"), "--extensions-dir", str(tmp / "extensions"), "--install-extension", str(vsix), "--force"], env=env, cwd=tmp, check=True, timeout=60)
        installed = json.loads((tmp / "extensions/extensions.json").read_text())
        entry = next(item for item in installed if item["identifier"]["id"].lower() == "gruntfuggly.todo-tree")
        assert entry["version"] == manifest["version"]
        assert entry.get("metadata", {}).get("pinned") is True, entry
        print("Patched Todo Tree installs through the native VS Code CLI.")
    else:
        print("VS Code is absent; installation check skipped.")
print("Todo Tree resolves live ~/.local/bin paths, including spaces and dollar signs.")
PY
