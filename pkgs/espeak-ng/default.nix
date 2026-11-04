{
  espeak-ng,
  lib,
  mbrola,
  fetchFromGitHub,
  nix-update-script,
  asyncSupport ? true,
  klattSupport ? true,
  mbrolaSupport ? true,
  pcaudiolibSupport ? true,
  sonicSupport ? true,
  speechPlayerSupport ? true,
}:
(espeak-ng.override {
  inherit asyncSupport klattSupport mbrolaSupport pcaudiolibSupport sonicSupport speechPlayerSupport;
}).overrideAttrs (finalAttrs: old: {
  version = "1.52.0-unstable-2026-11-03";
  src = fetchFromGitHub {
    owner = "espeak-ng";
    repo = "espeak-ng";
    rev = "a6ad07d4d7b58194ae671809bf194bc0ce967af9";
    hash = "sha256-Bk69mx4S9E+pIXmlo/uIqw4aGjZTmgRCxNU/4xUqhgE=";
  };
  # Upstream includes the backports and searches XDG paths for MBROLA voices.
  # Only the MBROLA executable still needs an absolute Nix path.
  patches = [];
  postPatch =
    (old.postPatch or "")
    + lib.optionalString mbrolaSupport ''
      substituteInPlace src/libespeak-ng/mbrowrap.c \
        --replace-fail 'execlp("mbrola",' 'execlp("${lib.getExe' mbrola "mbrola"}",'
    ''
    + ''
      printf '\n' >> dictsource/nl_list
      cat ${../../dotfiles/espeak-ng-1.52.0/nl_extra} >> dictsource/nl_list
    '';
  passthru =
    old.passthru
    // {
      updateScript = nix-update-script {
        extraArgs = ["--version" "branch"];
      };
    };
  postInstall =
    (old.postInstall or "")
    + ''
      test "$($out/bin/espeak-ng --path="$out/share" -q -v nl -x nixcfg)" = \
        "$($out/bin/espeak-ng --path="$out/share" -q -v nl -x 'niks config')"
    '';
  meta =
    old.meta
    // {
      changelog = "https://github.com/espeak-ng/espeak-ng/blob/${finalAttrs.src.rev}/ChangeLog.md";
    };
})
