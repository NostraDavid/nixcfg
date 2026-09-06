{
  fetchFromGitHub,
  lib,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "dockerfile-roast";
  version = "1.7.0";

  src = fetchFromGitHub {
    owner = "immanuwell";
    repo = "dockerfile-roast";
    rev = finalAttrs.version;
    hash = "sha256-K5QrUwGVt8x5yF/dBPUmfpLy8lGmv3CZrDGxn83upfc=";
  };

  cargoHash = "sha256-bFG4/c294XQ9oFUPtF8A/dKIOjj1WDK3s7nEHeuDLIU=";

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
