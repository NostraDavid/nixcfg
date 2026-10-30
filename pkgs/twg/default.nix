{
  lib,
  stdenvNoCC,
  fetchurl,
  glibc,
  makeWrapper,
}:
stdenvNoCC.mkDerivation (finalAttrs: let
  assets = {
    x86_64-linux = {
      name = "linux-x64";
      hash = "sha256-CGZixqoNnj2GyfLwABFbjMJI1jFSqx+T4iLpVRXQUgA=";
    };
    aarch64-darwin = {
      name = "darwin-arm64";
      hash = "sha256-W/CvcAB1NllVrU+Nkpc6ggCPbCs/fmB+OaZHBXs0B4Q=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
in {
  pname = "twg";
  version = "1.4.2";
  src = fetchurl {
    url = "https://teamwork-graph.atlassian.com/cli/twg-${asset.name}-v${finalAttrs.version}";
    inherit (asset) hash;
  };
  dontUnpack = true;
  dontFixup = true;
  nativeBuildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [makeWrapper];
  installPhase = ''
    runHook preInstall
    ${
      if stdenvNoCC.hostPlatform.isLinux
      then ''
        install -Dm755 "$src" "$out/libexec/twg"
        makeWrapper ${glibc}/lib/ld-linux-x86-64.so.2 "$out/bin/twg" \
          --add-flags "--library-path ${glibc}/lib $out/libexec/twg"
      ''
      else ''install -Dm755 "$src" "$out/bin/twg"''
    }
    runHook postInstall
  '';
  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    test "$(HOME="$TMPDIR" DO_NOT_TRACK=1 "$out/bin/twg" --version)" = "${finalAttrs.version}"
    runHook postInstallCheck
  '';
  meta = {
    description = "Atlassian Teamwork Graph CLI";
    homepage = "https://github.com/atlassian/twg-cli";
    license = lib.licenses.unfree;
    mainProgram = "twg";
    platforms = builtins.attrNames assets;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
  };
})
