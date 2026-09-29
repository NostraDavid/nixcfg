{
  autoPatchelfHook,
  fetchFromGitHub,
  fetchurl,
  lib,
  stdenvNoCC,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "ctx";
  version = "2.1.2";

  src = fetchurl {
    url = "https://github.com/ctxrs/ctx/releases/download/v${finalAttrs.version}/ctx-linux-x64";
    hash = "sha256-otyKTDfmaoQbs2X2GewH4xKiME4W5rciZj8LNt8E+jM=";
  };
  skillSource = fetchFromGitHub {
    owner = "ctxrs";
    repo = "ctx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-Cp7mT9nZNUjBh8peqQbfLdsmrAj4o9Sg+jZZypCbU5s=";
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
