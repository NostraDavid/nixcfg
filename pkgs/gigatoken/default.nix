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
      url = "https://files.pythonhosted.org/packages/45/b6/85e9a2351bf93897782bfcb58eacc64ac4d5b8654fb8ee463a830b1795e5/gigatoken-0.11.0-cp310-abi3-manylinux_2_17_x86_64.manylinux2014_x86_64.whl";
      hash = "sha256-EZkqvH9B5B5b4DxyLfHFIFtdD8xLy9T7RA0qC5f3rD8=";
    };
    aarch64-linux = {
      url = "https://files.pythonhosted.org/packages/28/16/76a482e25b44d36fc456ca285185ccc6555009aa8712217e8b26703479ee/gigatoken-0.11.0-cp310-abi3-manylinux_2_17_aarch64.manylinux2014_aarch64.whl";
      hash = "sha256-gWtor5phkn75X5zLqkx2cX3CDeD8q4RsAJDPFjMhuLo=";
    };
    x86_64-darwin = {
      url = "https://files.pythonhosted.org/packages/57/2d/fd78504d28b44474e87d0366a392e53703a17eb231599a3b96c01c9dd99f/gigatoken-0.11.0-cp310-abi3-macosx_10_12_x86_64.whl";
      hash = "sha256-i2rWeaXRsZFz3fpeGUM1Apikm5JntdVTAvV7Eo4jfQE=";
    };
    aarch64-darwin = {
      url = "https://files.pythonhosted.org/packages/6f/6b/5044db634b772f7262150c08a6b44c5eec07ed37adafff2d6bc817e8c8d0/gigatoken-0.11.0-cp310-abi3-macosx_11_0_arm64.whl";
      hash = "sha256-+IRpC/kBkYjBBnj9GIWMYtB0aNES2PHE7KfzuTzMYZU=";
    };
  };
  wheel = wheels.${python3Packages.python.stdenv.hostPlatform.system}
    or (throw "Unsupported gigatoken platform: ${python3Packages.python.stdenv.hostPlatform.system}");
in
  python3Packages.buildPythonApplication {
    pname = "gigatoken";
    version = "0.11.0";
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
