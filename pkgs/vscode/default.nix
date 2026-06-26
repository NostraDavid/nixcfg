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
  version = "1.126.0";
  # to grab the hash, run:
  # nix store prefetch-file https://update.code.visualstudio.com/<version>/linux-x64/stable
  srcHash = "sha256-fj2MxTByiFHl2r5rXN/J1mqG69uRNIvDZDujBG5cIxw=";
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
