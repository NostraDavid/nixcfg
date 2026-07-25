{
  lib,
  stdenv,
  stdenvAdapters,
  buildGoModule,
  fetchFromGitHub,
  nix-update-script,
  versionCheckHook,
}: let
  effectiveStdenv =
    if stdenv.hostPlatform.isLinux
    then stdenvAdapters.useMoldLinker stdenv
    else stdenv;
in
  (buildGoModule.override {stdenv = effectiveStdenv;}) rec {
    pname = "snip";
    version = "0.22.0";

    src = fetchFromGitHub {
      owner = "edouard-claude";
      repo = "snip";
      rev = "v${version}";
      hash = "sha256-y88ZHg29Z/QBZk8YWXp287Rel7DpPESYAlbqt5hj1nc=";
    };

    vendorHash = "sha256-2MxFZqjNuLzcuu+bsLyOyHIakCxh7j0FUx8LsjZRhrY=";

    subPackages = [
      "cmd/snip"
    ];

    ldflags = [
      "-s"
      "-w"
      "-X github.com/edouard-claude/snip/internal/cli.version=${version}"
    ];

    doInstallCheck = true;
    nativeInstallCheckInputs = [versionCheckHook];

    passthru.updateScript = nix-update-script {
      extraArgs = ["--flake"];
    };

    meta = with lib; {
      description = "CLI proxy that reduces LLM token usage with declarative filters";
      homepage = "https://github.com/edouard-claude/snip";
      changelog = "https://github.com/edouard-claude/snip/releases/tag/v${version}";
      license = licenses.mit;
      mainProgram = "snip";
      maintainers = [];
      platforms = platforms.unix;
    };
  }
