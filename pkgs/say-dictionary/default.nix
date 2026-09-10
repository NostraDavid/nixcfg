{
  stdenvNoCC,
  espeak-ng,
}:
stdenvNoCC.mkDerivation {
  pname = "say-dictionary";
  inherit (espeak-ng) version src;
  nativeBuildInputs = [espeak-ng];
  phases = ["unpackPhase" "installPhase"];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share"
    cp -r ${espeak-ng}/share/espeak-ng-data "$out/share/"
    chmod -R u+w "$out/share/espeak-ng-data"
    cd dictsource
    printf '\n' >> nl_extra
    cat ${../../dotfiles/say/nl_extra} >> nl_extra
    espeak-ng --path="$out/share" --compile=nl
    test "$(espeak-ng --path="$out/share" -q -v nl -x nixcfg)" = \
      "$(espeak-ng -q -v nl -x 'niks config')"
    runHook postInstall
  '';
}
