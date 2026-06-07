# Pin a specific upstream VS Code build by editing version/hash below.
# To change versions, replace `version` and `srcHash` with the release you need
# (including ones not yet packaged in nixpkgs).
{
  vscode,
  fetchurl,
  curl,
  openssl,
  ripgrep,
  webkitgtk_4_1,
  libsoup_3,
}: let
  version = "1.123.0";
  # to grab the hash, run:
  # nix store prefetch-file https://update.code.visualstudio.com/<version>/linux-x64/stable
  srcHash = "sha256-L975R3F779LgaFTL4B6ZtImPd1LyXhImnDgCPmO5PI8=";
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
      old.postPatch;
    # VS Code 1.109+ ships a Linux msal runtime that needs these libs.
    buildInputs =
      (old.buildInputs or [])
      ++ [
        curl
        openssl
        webkitgtk_4_1
        libsoup_3
      ];
  })
