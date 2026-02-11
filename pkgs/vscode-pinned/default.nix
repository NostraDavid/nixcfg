# Pin a specific upstream VS Code build by editing version/hash below.
# To change versions, replace `version` and `srcHash` with the release you need
# (including ones not yet packaged in nixpkgs).
{
  vscode,
  fetchurl,
  curl,
  openssl,
  webkitgtk_4_1,
  libsoup_3,
}: let
  version = "1.109.2";
  # to grab the hash, run:
  # nix store prefetch-file https://update.code.visualstudio.com/1.109.2/linux-x64/stable
  srcHash = "sha256-ST5i8gvNtAaBbmcpcg9GJipr8e5d0A0qbdG1P9QViek=";
  src = fetchurl {
    url = "https://update.code.visualstudio.com/${version}/linux-x64/stable";
    name = "vscode-${version}.tar.gz";
    hash = srcHash;
  };
in
  vscode.overrideAttrs (old: {
    inherit version src;
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
