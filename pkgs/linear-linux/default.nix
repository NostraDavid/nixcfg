{
  autoPatchelfHook,
  cairo,
  dpkg,
  fetchurl,
  gdk-pixbuf,
  glib,
  glib-networking,
  gtk3,
  lib,
  libappindicator-gtk3,
  libsoup_3,
  makeWrapper,
  pango,
  stdenv,
  webkitgtk_4_1,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "linear-linux";
  version = "0.2.3";

  src = fetchurl {
    url = "https://github.com/zacharyftw/linear-linux/releases/download/v${finalAttrs.version}/linear_${finalAttrs.version}_amd64.deb";
    hash = "sha256-Hp3fT1DAvemT3jlQEJqDF0iXwbQm0+WutM///O5j4YI=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
  ];

  buildInputs = [
    cairo
    gdk-pixbuf
    glib
    glib-networking
    gtk3
    libappindicator-gtk3
    libsoup_3
    pango
    webkitgtk_4_1
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R --no-preserve=ownership usr/. "$out/"
    runHook postInstall
  '';

  postFixup = ''
    mv "$out/bin/linear-linux" "$out/bin/linear-linux-unwrapped"
    makeWrapper "$out/bin/linear-linux-unwrapped" "$out/bin/linear-linux" --set GIO_EXTRA_MODULES "${glib-networking}/lib/gio/modules"
  '';

  meta = {
    description = "Unofficial Linear desktop client for Linux";
    homepage = "https://github.com/zacharyftw/linear-linux";
    license = lib.licenses.isc;
    mainProgram = "linear-linux";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
