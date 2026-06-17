{
  lib,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  mold,
  versionCheckHook,
}:
rustPlatform.buildRustPackage rec {
  pname = "jsongrep";
  version = "0.9.0";

  src = fetchFromGitHub {
    owner = "micahkepe";
    repo = "jsongrep";
    rev = "v${version}";
    hash = "sha256-rDt4jtrC+KuPKdEoReVWW8R9/sKBnalnRuB4bj1tzas=";
  };

  cargoHash = "sha256-VJ8ZB3oVppMRsSvpVOF1SIvOtI0rcS8elJEweoum/lY=";

  nativeBuildInputs = [
    installShellFiles
    mold
  ];

  env.RUSTFLAGS = "-C link-arg=-fuse-ld=mold";

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
  nativeInstallCheckInputs = [versionCheckHook];

  meta = {
    description = "JSONPath-inspired query language over JSON documents";
    homepage = "https://github.com/micahkepe/jsongrep";
    changelog = "https://github.com/micahkepe/jsongrep/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "jg";
    platforms = lib.platforms.unix;
  };
}
