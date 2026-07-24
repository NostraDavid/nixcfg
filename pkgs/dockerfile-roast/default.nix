{
  fetchFromGitHub,
  lib,
  nix-update-script,
  rustPlatform,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "dockerfile-roast";
  version = "1.4.8";

  src = fetchFromGitHub {
    owner = "immanuwell";
    repo = "dockerfile-roast";
    rev = finalAttrs.version;
    hash = "sha256-L17QnVlYVy0uT8vtm+zLTjNXyri1xVn/Ld4n3bXHyEo=";
  };

  cargoHash = "sha256-7ec2omH69SQUIWpLCaMKhTYub7yOY5ISYfMi5taPoeU=";

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
