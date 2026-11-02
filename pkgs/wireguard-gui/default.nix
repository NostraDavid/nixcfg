{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  makeWrapper,
  fontconfig,
  freetype,
  libxkbcommon,
  wayland,
  libGL,
  dbus,
  gtk3,
  glib,
  pango,
  cairo,
  gdk-pixbuf,
  wireguard-tools,
}:
rustPlatform.buildRustPackage (finalAttrs: {
  pname = "wireguard-gui";
  version = "1.9.3";

  src = fetchFromGitHub {
    owner = "JamilleJung";
    repo = "wireguard-gui";
    rev = "v${finalAttrs.version}";
    hash = "sha256-SkIbMAw6nv7oS0+6FIfrzpeEXjn76YTU1LU39qz5dAg=";
  };

  cargoLock.lockFile = "${finalAttrs.src}/Cargo.lock";

  # Polkit rejects authorization details from unprivileged callers.
  patches = [./polkit-helper.patch];

  nativeBuildInputs = [pkg-config makeWrapper];
  buildInputs = [fontconfig freetype libxkbcommon wayland libGL dbus gtk3 glib pango cairo gdk-pixbuf];

  postPatch = ''
    substituteInPlace src/bin/wg-helper.rs --replace-fail 'const FIXED_PATHS: [&str; 4] = ["/usr/sbin", "/usr/bin", "/sbin", "/bin"];' 'const FIXED_PATHS: [&str; 5] = ["/run/current-system/sw/bin", "/usr/sbin", "/usr/bin", "/sbin", "/bin"];'
  '';

  doCheck = false;

  postInstall = ''
    install -Dm755 $out/bin/wg-helper $out/libexec/wireguard-gui/wg-helper
    rm $out/bin/wg-helper
    install -Dm644 packaging/wireguard-gui.desktop $out/share/applications/wireguard-gui.desktop
    install -Dm644 packaging/wireguard-gui.svg $out/share/icons/hicolor/scalable/apps/wireguard-gui.svg
    install -Dm644 packaging/49-wireguard-gui.rules $out/share/polkit-1/rules.d/49-wireguard-gui.rules
    install -Dm644 ${./org.wireguard.gui.policy} $out/share/polkit-1/actions/org.wireguard.gui.policy
    wrapProgram $out/bin/wireguard-gui \
      --prefix PATH : ${lib.makeBinPath [wireguard-tools]} \
      --prefix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libxkbcommon wayland libGL]}
  '';

  meta = {
    description = "Native Linux GUI for managing WireGuard tunnels";
    homepage = "https://github.com/JamilleJung/wireguard-gui";
    license = lib.licenses.mit;
    mainProgram = "wireguard-gui";
    platforms = lib.platforms.linux;
  };
})
