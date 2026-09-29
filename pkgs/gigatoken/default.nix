{
  lib,
  fetchurl,
  git,
  python3Packages,
}: let
  o200kTokenizer = fetchurl {
    url = "https://openaipublic.blob.core.windows.net/encodings/o200k_base.tiktoken";
    hash = "sha256-RGqVOMtsNI41FhINfAiwn1fDZJXirP/+WaW/iwz7Gi0=";
  };
  wheels = {
    x86_64-linux = {
      url = "https://files.pythonhosted.org/packages/e7/32/a0b3af6db26b3704224d3ad856ebadfdb6ed5d50210ab16ab9ad27b30673/gigatoken-0.10.0-cp310-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-LzSB0MBnvqzxwKdkDZVu28iXMBS6jPo+GL+vsC945Ts=";
    };
    aarch64-linux = {
      url = "https://files.pythonhosted.org/packages/35/6f/d393a7735cbf775f612da4d0674f7ecc8900e0be4989fd46cbe23f650965/gigatoken-0.10.0-cp310-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      hash = "sha256-Rvcmt35BMpFPZO1Cx7gdgr3EDpMCE4/Kygs5Tu1i/Ec=";
    };
    x86_64-darwin = {
      url = "https://files.pythonhosted.org/packages/bf/fb/861532617e4804df169b4b4b7f62a73123fef77706af6046826e996cb718/gigatoken-0.10.0-cp310-abi3-macosx_10_12_x86_64.whl";
      hash = "sha256-qZWv4zyYwoMF3ssMvf7NAvVI5cQXbVyTUyqAMKaD0KE=";
    };
    aarch64-darwin = {
      url = "https://files.pythonhosted.org/packages/05/8c/89091815057ea41a1e81061704266de52ac12e5411bc66d5f1b33a3f85a8/gigatoken-0.10.0-cp310-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-3/h6Hal9aXGOSgwsAKfymlCd/a9pqfjYu5aClRPFFsg=";
    };
  };
  wheel = wheels.${python3Packages.python.stdenv.hostPlatform.system}
    or (throw "Unsupported gigatoken platform: ${python3Packages.python.stdenv.hostPlatform.system}");
in
  python3Packages.buildPythonApplication {
    pname = "gigatoken";
    version = "0.10.0";
    format = "wheel";

    src = fetchurl {inherit (wheel) url hash;};
    dontStrip = true;

    dependencies = with python3Packages; [
      awkward
      numpy
      typer
    ];

    postInstall = ''
      install -Dm644 ${./gigatoken.py} "$out/${python3Packages.python.sitePackages}/gigatoken/_wrapper.py"
      substituteInPlace "$out/${python3Packages.python.sitePackages}/gigatoken/_wrapper.py" \
        --replace-fail '@git@' '${lib.getExe git}' \
        --replace-fail '@o200kTokenizer@' '${o200kTokenizer}'
      cat > "$out/bin/gigatoken" <<EOF2
      #!${python3Packages.python.interpreter}
      from gigatoken._wrapper import main
      main()
      EOF2
      chmod +x "$out/bin/gigatoken"
    '';

    pythonImportsCheck = ["gigatoken"];

    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      bash ${./test-cli.sh} "$out/bin/gigatoken"
      runHook postInstallCheck
    '';

    meta = {
      description = "Gigatoken package with count, encode, decode, and benchmark CLI";
      homepage = "https://github.com/marcelroed/gigatoken";
      license = lib.licenses.mit;
      mainProgram = "gigatoken";
      platforms = builtins.attrNames wheels;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
