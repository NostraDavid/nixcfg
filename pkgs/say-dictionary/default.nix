{
  stdenvNoCC,
  espeak-ng,
  lib,
  mbrola,
  fetchFromGitHub,
  nix-update-script,
}:
stdenvNoCC.mkDerivation (finalAttrs: let
  speechEngine = espeak-ng.overrideAttrs (old: {
    inherit (finalAttrs) version src;
    # Upstream includes the backports and searches XDG paths for MBROLA voices.
    # Only the MBROLA executable still needs an absolute Nix path.
    patches = [];
    postPatch =
      (old.postPatch or "")
      + lib.optionalString espeak-ng.mbrolaSupport ''
        substituteInPlace src/libespeak-ng/mbrowrap.c \
          --replace-fail 'execlp("mbrola",' 'execlp("${lib.getExe' mbrola "mbrola"}",'
      '';
    meta =
      old.meta
      // {
        changelog = "https://github.com/espeak-ng/espeak-ng/blob/${finalAttrs.src.rev}/ChangeLog.md";
      };
  });
in {
  pname = "say-dictionary";
  version = "1.52.0-unstable-2026-09-22";
  src = fetchFromGitHub {
    owner = "espeak-ng";
    repo = "espeak-ng";
    rev = "ba90c8e9f440ad544f674a790bb5f53878b6ffc5";
    hash = "sha256-XHiNZQD9UG9rTLl5ZhbnYuZBLXv6pXA3HBCQAnnKEHk=";
  };
  nativeBuildInputs = [speechEngine];
  passthru = {
    inherit speechEngine;
    updateScript = nix-update-script {
      extraArgs = ["--version" "branch"];
    };
  };
  phases = ["unpackPhase" "installPhase"];

  installPhase = ''
    runHook preInstall
    mkdir -p "$out/share"
    cp -r ${speechEngine}/share/espeak-ng-data "$out/share/"
    chmod -R u+w "$out/share/espeak-ng-data"
    cd dictsource
    printf '\n' >> nl_extra
    cat ${../../dotfiles/say/nl_extra} >> nl_extra
    espeak-ng --path="$out/share" --compile=nl
    test "$(espeak-ng --path="$out/share" -q -v nl -x nixcfg)" = \
      "$(espeak-ng -q -v nl -x 'niks config')"
    runHook postInstall
  '';
})
