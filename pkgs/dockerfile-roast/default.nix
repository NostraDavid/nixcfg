{
  fetchFromGitHub,
  lib,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "dockerfile-roast";
  version = "1.4.12";

  src = fetchFromGitHub {
    owner = "immanuwell";
    repo = "dockerfile-roast";
    rev = finalAttrs.version;
    hash = "sha256-/FtIefjF+lqz33L7HuT9HnhInzqPEP3LWRDIA+r1qrU=";
  };

  cargoHash = "sha256-80x5wkv81tKf9lWlukjba74BjRRwIhw8XkkrpF90tyM=";

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
