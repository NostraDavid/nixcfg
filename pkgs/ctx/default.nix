{
  autoPatchelfHook,
  fetchFromGitHub,
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ctx";
  version = "1.4.3";

  src = fetchurl {
    url = "https://github.com/ctxrs/ctx/releases/download/v${finalAttrs.version}/ctx-linux-x64";
    hash = "sha256-V4EGkly9ixhe43mExa3DxsvjdUbj6Vpa4mJaQ6poehI=";
  };
  skillSource = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Fw51pB1ZUpEkvpJ/a0i6Rx2k5dUeKurBTcPiVUxD+JY=";
  };

  nativeBuildInputs = [autoPatchelfHook];
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
    platforms = ["x86_64-linux"];
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
