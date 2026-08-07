# Pin a specific upstream VS Code build by editing version/hash below.
# To change versions, replace `version` and `srcHash` with the release you need
# (including ones not yet packaged in nixpkgs).
{
  lib,
  vscode,
  fetchurl,
  curl,
  libei,
  libjpeg8,
  libxtst,
  openssl,
  pipewire,
  python3,
  ripgrep,
  webkitgtk_4_1,
  libsoup_3,
}: let
  version = "1.132.0";
  # to grab the hash, run:
  # nix store prefetch-file https://update.code.visualstudio.com/<version>/linux-x64/stable
  srcHash = "sha256-rNrw+lV72hcglW/2XKDeCWXpLWj5fi2yI0GYRACTeu0=";
  src = fetchurl {
    url = "https://update.code.visualstudio.com/${version}/linux-x64/stable";
    name = "vscode-${version}.tar.gz";
    hash = srcHash;
  };
in
  vscode.overrideAttrs (old: {
    inherit version src;
    postPatch =
      builtins.replaceStrings [
        ''
          rm resources/app/node_modules/@vscode/ripgrep/bin/rg
          ln -s ${ripgrep}/bin/rg resources/app/node_modules/@vscode/ripgrep/bin/rg
        ''
      ] [
        ''
          if [[ -d resources/app/node_modules/@vscode/ripgrep/bin ]]; then
            rm -f resources/app/node_modules/@vscode/ripgrep/bin/rg
            ln -s ${ripgrep}/bin/rg resources/app/node_modules/@vscode/ripgrep/bin/rg
          fi
        ''
      ]
      old.postPatch
      + ''
        # asar extraction drops the executable bit from the signature verifier.
        chmod +x resources/app/node_modules/@vscode/vsce-sign/bin/vsce-sign

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
        if replacements != 2:
            raise RuntimeError(
                "expected two Copilot file-copy operations, found {}".format(
                    replacements
                )
            )
        path.write_text(source)
        PY

        for rg in \
          resources/app/node_modules/@vscode/ripgrep/bin/rg \
          resources/app/node_modules/@vscode/ripgrep-universal/bin/linux-x64/rg \
          resources/app/extensions/copilot/node_modules/@github/copilot/sdk/ripgrep/bin/linux-x64/rg
        do
          if [[ -e "$rg" ]]; then
            rm -f "$rg"
            ln -s ${ripgrep}/bin/rg "$rg"
          fi
        done
      '';
    # VS Code 1.109+ ships a Linux msal runtime that needs these libs.
    buildInputs =
      (old.buildInputs or [])
      ++ [
        curl
        libei
        (lib.getOutput "out" libjpeg8)
        libxtst
        openssl
        pipewire
        webkitgtk_4_1
        libsoup_3
      ];
  })
