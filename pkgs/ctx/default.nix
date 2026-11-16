{
  autoPatchelfHook,
  fetchFromGitHub,
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  binaries = {
    x86_64-linux = {
      asset = "ctx-linux-x64";
      hash = "sha256-rOlvzhnXJ9VdidXjoCkgty2OfTq1ehyWN2Ia1IHZYiE=";
    };
    aarch64-darwin = {
      asset = "ctx-macos-arm64";
      hash = "sha256-OHbxwZesKm3HSuACCkqjo43TzwVchXFC2eT93PvYWT0=";
    };
    x86_64-darwin = {
      asset = "ctx-macos-x64";
      hash = "sha256-hYYIyFfYHwcFa71f3FIZ/SN6SV4jfsng9K7s8OPoImc=";
    };
  };
  binary = binaries.${stdenvNoCC.hostPlatform.system} or (throw "ctx: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "ctx";
    version = "2.4.1";

    src = fetchurl {
      url = "https://github.com/ctxrs/ctx/releases/download/v${finalAttrs.version}/${binary.asset}";
      inherit (binary) hash;
    };
    skillSource = fetchFromGitHub {
      owner = "ctxrs";
      repo = "ctx";
      tag = "v${finalAttrs.version}";
      hash = "sha256-owOMZcPBIDEstsiaik3piaItTMJwj30qsEfR44Btesw=";
    };

    nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
    dontUnpack = true;
    dontBuild = true;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/ctx"
      mkdir -p "$out/share/skills"
      cp -r "$skillSource/skills/ctx" "$out/share/skills/ctx"
      runHook postInstall
    '';

    meta = {
      description = "Search local coding-agent history and retrieve original sessions";
      homepage = "https://ctx.rs";
      license = lib.licenses.asl20;
      mainProgram = "ctx";
      platforms = builtins.attrNames binaries;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
