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
      hash = "sha256-i8IstFx/qazCBJo8dBklk5o9ooAe99O26cnE+usvzI0=";
    };
    aarch64-darwin = {
      asset = "ctx-macos-arm64";
      hash = "sha256-WIUxF+YqxGN43lxno77Ee1IO2Pu4CYmMSF7UtQ1MpkA=";
    };
    x86_64-darwin = {
      asset = "ctx-macos-x64";
      hash = "sha256-iS20MVQSf5Zf6ATKmuVIH9ZE2WovxDBuAw3m5XxaJqg=";
    };
  };
  binary = binaries.${stdenvNoCC.hostPlatform.system} or (throw "ctx: unsupported platform ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "ctx";
    version = "2.3.0";

    src = fetchurl {
      url = "https://github.com/ctxrs/ctx/releases/download/v${finalAttrs.version}/${binary.asset}";
      inherit (binary) hash;
    };
    skillSource = fetchFromGitHub {
      owner = "ctxrs";
      repo = "ctx";
      tag = "v${finalAttrs.version}";
      hash = "sha256-XihSpW86eVALViD9mnSWXHldXI11T9N0uyHdlLXb9GU=";
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
