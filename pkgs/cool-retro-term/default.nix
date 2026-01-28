{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6Packages,
  nixosTests,
}:
stdenv.mkDerivation rec {
  version = "2.0.0-beta1";
  pname = "cool-retro-term";

  src = fetchFromGitHub {
    owner = "Swordfish90";
    repo = "cool-retro-term";
    tag = version;
    # 2.0.0-beta1 uses git submodules (qmltermwidget, KDSingleApplication).
    fetchSubmodules = true;
    hash = "sha256-zr/10rBRJ40EmX1wTB9QZuQAljPHoWCDPiS2/6GVfVs=";
  };

  buildInputs = [
    qt6Packages.qtbase
    # QML/Quick modules are in qtdeclarative for Qt 6.
    qt6Packages.qtdeclarative
    # QML imports Qt5Compat.GraphicalEffects.
    qt6Packages.qt5compat
    # QMLTermWidget uses Qt Multimedia.
    qt6Packages.qtmultimedia
  ];

  nativeBuildInputs = [
    qt6Packages.qmake
    # Wrap Qt apps so QML imports and plugins are found at runtime.
    qt6Packages.wrapQtAppsHook
    # Qt 6 shader baking tool (qsb) used by app.pro.
    qt6Packages.qtshadertools
  ];

  # Ensure QMLTermWidget installs into $out so wrapping can find it.
  qmakeFlags = [ "QT_INSTALL_QML=${placeholder "out"}/lib/qt-6/qml" ];

  installFlags = ["INSTALL_ROOT=$(out)"];

  postInstall = ''
    # qmake installs QML modules to the absolute QT_INSTALL_QML prefix; with
    # INSTALL_ROOT this ends up under $out/nix/store/.../lib/qt-6/qml.
    # Move the module into $out so wrapQtAppsHook can find it.
    if [ -d "$out/nix/store" ]; then
      shopt -s nullglob
      for qml_root in "$out"/nix/store/*-qtbase-*/lib/qt-6/qml; do
        if [ -d "$qml_root/QMLTermWidget" ]; then
          mkdir -p "$out/lib/qt-6/qml"
          cp -a "$qml_root/QMLTermWidget" "$out/lib/qt-6/qml/"
        fi
      done
      rm -rf "$out/nix"
    fi
  '';

  preFixup =
    ''
      mv $out/usr/share $out/share
      mv $out/usr/bin $out/bin
      rmdir $out/usr
    ''
    + lib.optionalString stdenv.hostPlatform.isDarwin ''
      ln -s $out/bin/cool-retro-term.app/Contents/MacOS/cool-retro-term $out/bin/cool-retro-term
    '';

  passthru.tests.test = nixosTests.terminal-emulators.cool-retro-term;

  meta = {
    description = "Terminal emulator which mimics the old cathode display";
    longDescription = ''
      cool-retro-term is a terminal emulator which tries to mimic the look and
      feel of the old cathode tube screens. It has been designed to be
      eye-candy, customizable, and reasonably lightweight.
    '';
    homepage = "https://github.com/Swordfish90/cool-retro-term";
    license = lib.licenses.gpl3Plus;
    platforms = with lib.platforms; linux ++ darwin;
    maintainers = [];
    mainProgram = "cool-retro-term";
  };
}
