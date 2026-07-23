{
  lib,
  fetchFromGitHub,
  git,
  python3Packages,
  rustPlatform,
}:
python3Packages.buildPythonApplication (finalAttrs: {
  pname = "gigatoken";
  version = "0.9.0";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "marcelroed";
    repo = "gigatoken";
    rev = "ecf968da2b7300e33f90e8bd9c96a11a335a01ae";
    hash = "sha256-xzrXzCvbvic9EoA8oKJJGIkhQCasbdvioyyw4RkfIAM=";
  };

  cargoDeps = rustPlatform.fetchCargoVendor {
    inherit (finalAttrs) pname version src;
    hash = "sha256-z1sOT3QqpdkFVMe9naNEnYaGM0JRZVGoeTv+jlQlfRQ=";
  };

  postPatch = ''
    # The profiling-only rustflags need nightly Cargo, but are irrelevant to
    # the release build produced by maturin.
    rm .cargo/config.toml
    substituteInPlace Cargo.toml \
      --replace-fail 'rustflags = ["-C", "force-frame-pointers=yes"]' '# rustflags removed for the release build'
    substituteInPlace pyproject.toml \
      --replace-fail 'gigatoken = "gigatoken._cli:app"' 'gigatoken = "gigatoken._wrapper:main"'
    cp ${./gigatoken.py} gigatoken/_wrapper.py
    substituteInPlace gigatoken/_wrapper.py \
      --replace-fail '@git@' '${lib.getExe git}'
  '';

  # Gigatoken uses the still-unstable portable_simd feature.
  env.RUSTC_BOOTSTRAP = 1;

  nativeBuildInputs = [
    rustPlatform.cargoSetupHook
    rustPlatform.maturinBuildHook
  ];

  dependencies = with python3Packages; [
    awkward
    numpy
    typer
  ];

  pythonImportsCheck = ["gigatoken"];

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    bash ${./test-cli.sh} \
      $out/bin/gigatoken \
      tests/fixtures/gpt2_tokenizer.json
    runHook postInstallCheck
  '';

  meta = {
    description = "Gigatoken package with count, encode, decode, and benchmark CLI";
    homepage = "https://github.com/marcelroed/gigatoken";
    license = lib.licenses.mit;
    mainProgram = "gigatoken";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
})
