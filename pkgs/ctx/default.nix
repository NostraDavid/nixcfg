{
  autoPatchelfHook,
  fetchFromGitHub,
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ctx";
  version = "2.3.0";

  src = fetchurl {
    url = "https://github.com/ctxrs/ctx/releases/download/v${finalAttrs.version}/ctx-linux-x64";
    hash = "sha256-i8IstFx/qazCBJo8dBklk5o9ooAe99O26cnE+usvzI0=";
  };
  skillSource = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-XihSpW86eVALViD9mnSWXHldXI11T9N0uyHdlLXb9GU=";
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
