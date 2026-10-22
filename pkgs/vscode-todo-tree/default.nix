{
  lib,
  python3,
  runCommand,
  vscode-extensions,
}: let
  upstream = vscode-extensions.gruntfuggly.todo-tree;
in
  runCommand "todo-tree-native-paths-${upstream.version}.vsix" {
    inherit (upstream) version;
    nativeBuildInputs = [python3];
    TODO_TREE_VSIX = upstream.src;
    meta = {
      description = "Todo Tree with home-relative executable paths";
      inherit (upstream.meta) homepage license;
      platforms = lib.platforms.all;
    };
  } ''
    python - <<'PY'
    import os
    from zipfile import ZipFile, ZIP_DEFLATED

    # shortcut: patch the pinned bundle; remove when upstream resolves ~/ paths.
    original = 'function t(e){return i.existsSync(e)?e:void 0}'
    replacement = 'function t(e){if(typeof e!=="string")return;if(e.startsWith("~/"))e=require("os").homedir()+e.slice(1);return i.existsSync(e)?e:void 0}'
    patched = False
    with ZipFile(os.environ["TODO_TREE_VSIX"]) as source, ZipFile(os.environ["out"], "w") as target:
        for entry in source.infolist():
            data = source.read(entry)
            if entry.filename == "extension/dist/extension.js":
                text = data.decode()
                if text.count(original) != 1:
                    raise RuntimeError("Todo Tree's ripgrep lookup changed; review the native path patch")
                data = text.replace(original, replacement).encode()
                patched = True
            entry.date_time = (1980, 1, 1, 0, 0, 0)
            entry.compress_type = ZIP_DEFLATED
            target.writestr(entry, data)
    if not patched:
        raise RuntimeError("Todo Tree's extension bundle was not found")
    PY
  ''
