{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:
stdenvNoCC.mkDerivation {
  pname = "win11os-kde";
  version = "unstable-2025-06-26";

  src = fetchFromGitHub {
    owner = "yeyushengfan258";
    repo = "Win11OS-kde";
    rev = "9f021c3e71da7baf59a0614ab858d53b1e455fd5";
    hash = "sha256-R1l0YG+UEfFKPJd/pQJ3aJzWKg1ru0gWasW7zStK1Ig=";
  };

  installPhase = ''
    runHook preInstall

    mkdir -p $out/share/aurorae/themes
    mkdir -p $out/share/color-schemes
    mkdir -p $out/share/plasma/desktoptheme
    mkdir -p $out/share/plasma/look-and-feel
    mkdir -p $out/share/wallpapers
    mkdir -p $out/share/sddm/themes

    cp -r aurorae/* $out/share/aurorae/themes/
    cp -r color-schemes/*.colors $out/share/color-schemes/
    cp -r plasma/desktoptheme/* $out/share/plasma/desktoptheme/
    cp -r plasma/look-and-feel/* $out/share/plasma/look-and-feel/
    cp -r wallpaper/* $out/share/wallpapers/
    cp -r sddm-dark/6.0/Win11OS-dark $out/share/sddm/themes/Win11OS-dark
    cp -r sddm-light/6.0/Win11OS-light $out/share/sddm/themes/Win11OS-light

    darkLookAndFeel=$out/share/plasma/look-and-feel/com.github.yeyushengfan258.Win11OS-dark
    mkdir -p "$darkLookAndFeel/contents/lockscreen"
    cp ${./lockscreen}/* "$darkLookAndFeel/contents/lockscreen/"
    cp sddm-dark/6.0/Win11OS-dark/background.jpeg \
      "$darkLookAndFeel/contents/lockscreen/background.jpeg"

    runHook postInstall
  '';

  meta = {
    description = "Win11OS kde - a materia Design theme for KDE Plasma desktop";
    homepage = "https://github.com/yeyushengfan258/Win11OS-kde";
    license = lib.licenses.gpl3Only;
    platforms = lib.platforms.linux;
  };
}
