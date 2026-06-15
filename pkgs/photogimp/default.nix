{
  fetchFromGitHub,
  stdenvNoCC,
}: let
  version = "3.0";
in
  stdenvNoCC.mkDerivation {
    pname = "photogimp";
    inherit version;

    src = fetchFromGitHub {
      owner = "Diolinux";
      repo = "PhotoGIMP";
      rev = version;
      hash = "sha256-R9MMidsR2+QFX6tu+j5k2BejxZ+RGwzA0DR9GheO89M=";
    };

    installPhase = ''
      runHook preInstall

      mkdir -p "$out/share/photogimp" "$out/share/applications" "$out/share/icons"
      cp -r .var/app/org.gimp.GIMP/config/GIMP "$out/share/photogimp/"
      cp -r .local/share/icons/* "$out/share/icons/"

      runHook postInstall
    '';
  }
