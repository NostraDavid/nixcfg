{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versionCheckHook,
}:
buildGoModule rec {
  pname = "snip";
  version = "0.20.0";

  src = fetchFromGitHub {
    owner = "edouard-claude";
    repo = "snip";
    rev = "v${version}";
    hash = "sha256-u6Jc9U4tb5Y/evtWR/Nw535xVh09ChcKN0Dm+l3bjvA=";
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

  meta = {
    description = "CLI proxy that reduces LLM token usage with declarative filters";
    homepage = "https://github.com/edouard-claude/snip";
    changelog = "https://github.com/edouard-claude/snip/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "snip";
    platforms = lib.platforms.unix;
  };
}
