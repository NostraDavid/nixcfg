# DLSS Updater
{ lib
, stdenvNoCC
, fetchurl
, makeWrapper
, flatpak
, gnugrep
}:

let
  version = "3.6.1";
  src = fetchurl {
    url = "https://github.com/Recol/DLSS-Updater/releases/download/V${version}/DLSS_Updater-${version}.flatpak";
    hash = "sha256-3Wi0eZ9ngCFWgoclEsz4baNi+MvBabmOWgdlJrm9qy4=";
  };
in stdenvNoCC.mkDerivation {
  pname = "dlss-updater";
  inherit version src;

  dontUnpack = true;

  nativeBuildInputs = [ makeWrapper ];
  buildInputs = [ flatpak ];

  installPhase = ''
    runHook preInstall

    install -Dm644 "$src" "$out/share/dlss-updater/DLSS_Updater.flatpak"
    makeWrapper "${flatpak}/bin/flatpak" "$out/bin/dlss-updater" \
      --add-flags "--user run io.github.recol.dlss-updater" \
      --run "if ! ${flatpak}/bin/flatpak --user info io.github.recol.dlss-updater >/dev/null 2>&1; then \
        if ! ${flatpak}/bin/flatpak --user remotes | ${lib.getExe gnugrep} -q '^flathub\\b'; then \
          ${flatpak}/bin/flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo || exit 1; \
        fi; \
        ${flatpak}/bin/flatpak --user install --noninteractive --assumeyes flathub org.freedesktop.Platform//24.08 || exit 1; \
        ${flatpak}/bin/flatpak --user install --noninteractive --assumeyes --bundle $out/share/dlss-updater/DLSS_Updater.flatpak || exit 1; \
      fi"

    runHook postInstall
  '';

  meta = {
    description = "DLSS Updater Flatpak bundle and launcher";
    homepage = "https://github.com/Recol/DLSS-Updater";
    license = lib.licenses.agpl3Only;
    mainProgram = "dlss-updater";
    platforms = lib.platforms.linux;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
