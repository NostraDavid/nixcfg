{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  rev = "2d6f4b2c598b85f15b493925f2273088c1b1a1d4";
  assets = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-eo0aP60CJMCbofOZLCnrGxMIfNM/TcJ3RYivRuK5SCg=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-hPQyywRtEypqTAcBPrcXvOkm39VWhoGGjGqZf6Loy9M=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-46ruGolkRobU8ErqC9Ed87e97sZUYR+jKKt1zkWNF5w=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-fCeNrnU8ZNT7Xuy1djAHQF2wMuRMbClf5LpSUVNoMk0=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported cmux TUI platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation {
    pname = "cmux-tui";
    version = "0.1.0-unstable-2026-10-20";
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
