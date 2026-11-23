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
      hash = "sha256-uKI4htmct9Tpht3W6JZCI440639k+jmleqhwq6FpoLA=";
    };
    aarch64-darwin = {
      asset = "ctx-macos-arm64";
      hash = "sha256-+0VSug66Y9pfFSbNJ7xJ28ZHXAgcgyyFcePSmBTjRAE=";
    };
    x86_64-darwin = {
      asset = "ctx-macos-x64";
      hash = "sha256-gAOdjM+omZswTlvSs2fxGOU7S0M62JSjqrgMrcA3Qm0=";
    };
  };
  binary = binaries.${stdenvNoCC.hostPlatform.system} or (throw "ctx: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "ctx";
    version = "2.5.0";

    src = fetchurl {
      url = "https://github.com/ctxrs/ctx/releases/download/v${finalAttrs.version}/${binary.asset}";
      inherit (binary) hash;
    };
    skillSource = fetchFromGitHub {
      owner = "ctxrs";
      repo = "ctx";
      tag = "v${finalAttrs.version}";
      hash = "sha256-aCb+6mhCtXNMWLBItRCwgoXjzHdLxN8nyNAvsFLMZCs=";
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
