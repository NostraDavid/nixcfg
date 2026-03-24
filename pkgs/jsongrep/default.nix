{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  versionCheckHook,
}:
rustPlatform.buildRustPackage rec {
  pname = "jsongrep";
  version = "0.7.0";

  src = fetchFromGitHub {
    owner = "micahkepe";
    repo = "jsongrep";
    rev = "v${version}";
    hash = "sha256-pjPPvYGCIq10tzSu73bOmd06aBD9wKo/FyIFdgLXUC8=";
  };

  cargoHash = "sha256-zAInnlduZdMEf5SakZahmgjndeZAN2ChPZo7F7mZpkQ=";

  nativeBuildInputs = [
    installShellFiles
  ];

  postInstall = ''
    local tmpdir
    tmpdir="$(mktemp -d)"

    $out/bin/jg generate shell bash > "$tmpdir/jg.bash"
    $out/bin/jg generate shell fish > "$tmpdir/jg.fish"
    $out/bin/jg generate shell zsh > "$tmpdir/_jg"
    $out/bin/jg generate man --output-dir "$tmpdir/man"

    installShellCompletion --cmd jg \
      --bash "$tmpdir/jg.bash" \
      --fish "$tmpdir/jg.fish" \
      --zsh "$tmpdir/_jg"
    installManPage "$tmpdir/man/"*.1
  '';

  doInstallCheck = true;
  nativeInstallCheckInputs = [ versionCheckHook ];

  meta = {
    description = "JSONPath-inspired query language over JSON documents";
    homepage = "https://github.com/micahkepe/jsongrep";
    changelog = "https://github.com/micahkepe/jsongrep/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "jg";
    platforms = lib.platforms.unix;
  };
}
