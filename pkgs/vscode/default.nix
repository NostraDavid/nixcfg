# Pin a specific upstream VS Code build by editing version/hash below.
# To change versions, replace `version` and `srcHash` with the release you need
# (including ones not yet packaged in nixpkgs).
{ vscode, fetchurl }: let
  version = "1.106.0";
  # to grab the hash, run:
  # nix store prefetch-file https://update.code.visualstudio.com/1.106.0/linux-x64/stable
  srcHash = "sha256-C+VAuyK2/4unyQm6h0lJJnAMFpGZYC3v8qPaeHkL8gE=";
  src = fetchurl {
    url = "https://update.code.visualstudio.com/${version}/linux-x64/stable";
    name = "vscode-${version}.tar.gz";
    hash = srcHash;
  };
in vscode.overrideAttrs (_: {
  inherit version src;
})
