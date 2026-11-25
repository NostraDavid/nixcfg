# Pin a specific upstream VS Code build by editing version/hash below.
{
  lib,
  vscode,
  fetchurl,
  curl,
  openssl,
  python3,
  ripgrep,
  stdenvNoCC,
}: let
  version = "1.148.0";
  # to grab the hash, run:
  # nix store prefetch-file https://update.code.visualstudio.com/<version>/linux-x64/stable
  srcHash = "sha256-es2vAaHXonxVgoFW7D/b51uOCAkHD+zRDeAixJgqDxY=";
  src = fetchurl {
    url = "https://update.code.visualstudio.com/${version}/linux-x64/stable";
    name = "vscode-${version}.tar.gz";
    hash = srcHash;
  };
in
  if stdenvNoCC.hostPlatform.system != "x86_64-linux"
  then vscode
  else
    vscode.overrideAttrs (old: {
      inherit version src;
      postPatch =
        old.postPatch
        + ''
          ${lib.getExe python3} - <<'PY'
          import re
          from pathlib import Path

          path = Path("resources/app/extensions/copilot/dist/extension.js")
          source = path.read_text()
          copy_pattern = re.compile(
              r"await (?P<fs>[\w$]+)\.promises\.copyFile\("
              r"(?P<join>[\w$]+)\(__dirname,(?P<name>[\w$]+)\),"
              r"(?P=join)\((?P<directory>[\w$]+),(?P=name)\)\)"
          )

          def make_writable(match):
              fs = match["fs"]
              target = "{}({},{})".format(
                  match["join"], match["directory"], match["name"]
              )
              return "{},await {}.promises.chmod({},420)".format(
                  match.group(0), fs, target
              )

          source, replacements = copy_pattern.subn(make_writable, source)
          if replacements != 1:
              raise RuntimeError(
                  "expected one Copilot file-copy operation, found {}".format(
                      replacements
                  )
              )
          path.write_text(source)
          PY

          rg=resources/app/extensions/copilot/node_modules/@github/copilot/sdk/ripgrep/bin/linux-x64/rg
          test -f "$rg"
          ln -sf ${ripgrep}/bin/rg "$rg"
        '';
      # The bundled Microsoft Authentication library links libcurl and libcrypto.
      buildInputs = old.buildInputs ++ [curl openssl];
    })
