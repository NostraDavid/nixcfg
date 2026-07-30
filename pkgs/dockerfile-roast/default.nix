{
  fetchFromGitHub,
  lib,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "dockerfile-roast";
  version = "1.4.11";

  src = fetchFromGitHub {
    owner = "immanuwell";
    repo = "dockerfile-roast";
    rev = finalAttrs.version;
    hash = "sha256-PcrCsunROEsihepKUX15mLLxXdkawECXQXOM5kDLvY0=";
  };

  cargoHash = "sha256-Uz0FIxSO7nx/JSKIt3OXg9UHmGXY4mXjVOSB9fgi9aU=";

  # Four discovery tests in the 1.4.8 release expect 13 fixtures, but find 14.
  doCheck = false;

  passthru.updateScript = nix-update-script {
    extraArgs = [
      "--flake"
      "--url=https://github.com/immanuwell/dockerfile-roast"
      "--use-github-releases"
      "--version-regex=^(\\d+\\.\\d+\\.\\d+)$"
    ];
  };

  meta = {
    description = "Opinionated Dockerfile linter";
    homepage = "https://github.com/immanuwell/dockerfile-roast";
    changelog = "https://github.com/immanuwell/dockerfile-roast/releases/tag/${finalAttrs.version}";
    license = lib.licenses.mit;
    mainProgram = "droast";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
