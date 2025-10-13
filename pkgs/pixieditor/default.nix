{
  lib,
  stdenv,
  fetchzip,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  atk,
  cairo,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  gtk3,
  icu,
  libdrm,
  libglvnd,
  libICE,
  libSM,
  libunwind,
  libuuid,
  libxcb,
  libX11,
  libXcomposite,
  libXcursor,
  libXdamage,
  libXext,
  libXfixes,
  libXi,
  libXinerama,
  libXrandr,
  libXrender,
  libXScrnSaver,
  libXtst,
  lttng-ust_2_12,
  mesa,
  openssl,
  pango,
  systemd,
  zlib,
}:
stdenv.mkDerivation rec {
  pname = "pixieditor";
  version = "2.0.1.17";

  src = fetchzip {
    url = "https://github.com/PixiEditor/PixiEditor/releases/download/${version}/PixiEditor-${version}-amd64-linux.tar.gz";
    hash = "sha256-n25Zx+3NQjtpzUiUb0iG9wZTW5dSmopOUvIQ5i9x2t4=";
    stripRoot = false;
  };

  sourceRoot = "source";

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = [
    alsa-lib
    atk
    cairo
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    gtk3
    icu
    libdrm
    libglvnd
    libICE
    libSM
    libunwind
    libuuid
    libxcb
    libX11
    libXcomposite
    libXcursor
    libXdamage
    libXext
    libXfixes
    libXi
    libXinerama
    libXrandr
    libXrender
    libXScrnSaver
    libXtst
    lttng-ust_2_12
    mesa
    openssl
    pango
    stdenv.cc.cc
    systemd
    zlib
  ];

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
        runHook preInstall

        install -dm755 "$out/lib"
        cp -rT . "$out/lib/pixieditor"

        install -Dm644 "$out/lib/pixieditor/Assets/PixiEditorLogo.png" \
          "$out/share/icons/hicolor/256x256/apps/pixieditor.png"

      cat > pixieditor.desktop <<'EOF'
    [Desktop Entry]
    Name=PixiEditor
    GenericName=Pixel Art Editor
    Comment=Create and animate pixel art
    Exec=pixieditor
    Icon=pixieditor
    Categories=Graphics;2DGraphics;RasterGraphics;Qt;
    Terminal=false
    Type=Application
    StartupWMClass=PixiEditor
    MimeType=image/png;image/gif;image/jpeg;
    EOF

      install -Dm644 pixieditor.desktop "$out/share/applications/pixieditor.desktop"

      runHook postInstall
  '';

  postFixup = ''
    rm pixieditor.desktop

    makeWrapper "$out/lib/pixieditor/PixiEditor" "$out/bin/pixieditor" \
      --prefix PATH : ${lib.makeBinPath [dbus]} \
      --suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath [
      alsa-lib
      atk
      cairo
      dbus
      expat
      fontconfig
      freetype
      gdk-pixbuf
      glib
      gtk3
      icu
      libdrm
      libglvnd
      libICE
      libSM
      libunwind
      libuuid
      libxcb
      libX11
      libXcomposite
      libXcursor
      libXdamage
      libXext
      libXfixes
      libXi
      libXinerama
      libXrandr
      libXrender
      libXScrnSaver
      libXtst
      lttng-ust_2_12
      mesa
      openssl
      pango
      stdenv.cc.cc
      systemd
      zlib
    ]} \
      --set QT_QPA_PLATFORM xcb \
    --set DOTNET_BUNDLE_EXTRACT_BASE_DIR "''${XDG_CACHE_HOME:-\$HOME/.cache}/pixieditor"
  '';

  meta = with lib; {
    description = "Modern pixel art editor for Windows, Linux, and macOS";
    homepage = "https://pixieditor.net";
    license = licenses.lgpl3Plus;
    maintainers = with maintainers; [dbreyfogle];
    platforms = platforms.linux;
    mainProgram = "pixieditor";
    sourceProvenance = with sourceTypes; [binaryNativeCode];
  };
}
