{
  lib,
  fetchurl,
  git,
  python3Packages,
  rustPlatform,
}: let
  o200kTokenizer = fetchurl {
    url = "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken";
    hash = "sha256-RGqVOMtsNI41FhINfAiwn1fDZJXirP/+WaW/iwz7Gi0=";
  };
in
  python3Packages.buildPythonApplication (finalAttrs: {
    pname = "gigatoken";
    version = "0.10.0";
    pyproject = true;

    src = fetchurl {
      url = "https://files.pythonhosted.org/packages/33/8a/fa097b404650a9eaea59de80bc8c33ad8ccb6b4a17ff6f33f213ec091057/gigatoken-0.10.0.tar.gz";
      hash = "sha256-Vi/UKE6s3r2KgEPOId3NrLYSEKA25ucAzRO9yisq96w=";
    };

    cargoDeps = rustPlatform.fetchCargoVendor {
      inherit (finalAttrs) pname version src;
      hash = "sha256-9CiXqxJcu2ve0ypQL0uGTvTz4cE8qwMsPGIMG1BuPCs=";
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
        --replace-fail '@git@' '${lib.getExe git}' \
        --replace-fail '@o200kTokenizer@' '${o200kTokenizer}'
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
