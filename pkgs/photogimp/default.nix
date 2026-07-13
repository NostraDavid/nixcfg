{
  fetchFromGitHub,
  stdenvNoCC,
}: let
  version = "3.1";
in
  stdenvNoCC.mkDerivation {
    pname = "photogimp";
    inherit version;

    src = fetchFromGitHub {
      owner = "Diolinux";
      repo = "PhotoGIMP";
      rev = version;
      hash = "sha256-524lsDRmahWXXP9/cfk2ia+7K6xNFTdoYXO8UUsLP/o=";
    };

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/photogimp" "$out/share/applications" "$out/share/icons"
      cp -r .config/GIMP "$out/share/photogimp/"
      cp -r .local/share/icons/* "$out/share/icons/"

      runHook postInstall
    '';
  }
