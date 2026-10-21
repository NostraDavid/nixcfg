{
  lib,
  plocate,
  fetchFromGitHub,
  stdenvNoCC,
  zstd,
}:
plocate.overrideAttrs (old: {
  version = "1.1.24-unstable-2025-03-11";
  src = fetchFromGitHub {
    owner = "jevinskie";
    repo = "plocate-xnu";
    rev = "4bfea2886010d1d4bcf63cac9b83753d1ab00cde";
    hash = "sha256-tSotT4f9dqycF1Bn3PgOhsQg6gDdkBLVIpcI+YCx8aY=";
  };
  buildInputs = [zstd];
  mesonFlags = [
    "-Dinstall_systemd=false"
    "-Dsharedstatedir=/var/db"
    "-Ddbpath=plocate/plocate.db"
    "-Dlocategroup=nobody"
  ];
  postInstall = ''
    ln -s plocate "$out/bin/locate"
  '';
  doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
  installCheckPhase = ''
    runHook preInstallCheck
    mkdir -p "$TMPDIR/plocate-test"
    touch "$TMPDIR/plocate-test/plocate-test-marker"
    "$out/bin/updatedb" --require-visibility=no \
      --database-root="$TMPDIR/plocate-test" --output="$TMPDIR/plocate-test.db"
    "$out/bin/locate" --database="$TMPDIR/plocate-test.db" plocate-test-marker \
      | grep -Fx "$TMPDIR/plocate-test/plocate-test-marker"
    runHook postInstallCheck
  '';
  meta =
    old.meta
    // {
      homepage = "https://github.com/jevinskie/plocate-xnu";
      platforms = lib.platforms.darwin;
      mainProgram = "plocate";
    };
})
