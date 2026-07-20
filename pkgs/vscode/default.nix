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
  ripgrep,
  webkitgtk_4_1,
  libsoup_3,
}: let
  version = "1.129.1";
  # to grab the hash, run:
  # nix store prefetch-file https://update.code.visualstudio.com/<version>/linux-x64/stable
  srcHash = "sha256-cieB7O7HQ2oJVFT4OfmaToXHh6pFPpBk7dltKZ8CSVM=";
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
        substituteInPlace resources/app/extensions/copilot/dist/extension.js \
          --replace-fail \
            'await O4.promises.copyFile(gr(__dirname,xKt),gr(r,xKt))' \
            'await O4.promises.copyFile(gr(__dirname,xKt),gr(r,xKt)),await O4.promises.chmod(gr(r,xKt),420)' \
          --replace-fail \
            'await K$.promises.copyFile(gr(__dirname,scn),gr(t,scn))' \
            'await K$.promises.copyFile(gr(__dirname,scn),gr(t,scn)),await K$.promises.chmod(gr(t,scn),420)'

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
