{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  rev = "6dc229ca0c47ea12babc0c22ffceae59e81d5109";
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-uC5zdPlKq0tHQGVF0KO1JPE08AhRq/Y2S7UVymcLLqI=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-Jkl7uALnQt9ZL8E8rS2f6oGqzIsYhzVT9SI/yJG/N+8=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported cmux TUI platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation {
    pname = "cmux-tui";
    version = "0.1.0-unstable-2026-10-15";
    src = fetchurl {
      url = "https://files.cmux.com/cmux-tui/${rev}/cmux-tui-${asset.target}";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
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
