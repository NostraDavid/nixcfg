{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  rev = "a6d89d443f5f9ffb66c296d7a9680e307bbe6c58";
  assets = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-++trvGR0pCbcl+AFX8fx0bqO4Q/UZRWQbRNnCdyW07k=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-K66kRXrQH++Q1GdcjHmeFuCNZ+aS3Wn2zRatz2v+fwo=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-VZmyzRjTWHrP7qLwLUL4Ay1yXhWx4jtVYgQF5hu+kEM=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-hCX+3v+n6LpYuhJvXz0AIqCSpHETxNWYIBUKyBs/1tU=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported cmux TUI platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation {
    pname = "cmux-tui";
    version = "0.1.0-unstable-2026-10-29";
    src = fetchurl {
      url = "https://files.cmux.com/cmux-tui/${rev}/cmux-tui-${asset.target}";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    # Preserve the upstream Mach-O signature.
    dontStrip = stdenvNoCC.hostPlatform.isDarwin;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/cmux"
      runHook postInstall
    '';

    doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/cmux" --version | grep -F '${rev}'
      "$out/bin/cmux" --help > /dev/null
      runHook postInstallCheck
    '';

    meta = {
      description = "Terminal multiplexer with workspaces, split panes and a control socket";
      homepage = "https://cmux.com/docs/tui";
      license = lib.licenses.mit;
      mainProgram = "cmux";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
