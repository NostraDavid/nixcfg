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
  version = "1.52.0-unstable-2026-09-22";
  src = fetchFromGitHub {
    owner = "espeak-ng";
    repo = "espeak-ng";
    rev = "ba90c8e9f440ad544f674a790bb5f53878b6ffc5";
    hash = "sha256-XHiNZQD9UG9rTLl5ZhbnYuZBLXv6pXA3HBCQAnnKEHk=";
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
