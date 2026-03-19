{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  curl,
  xdg-utils,
}:
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "dpaint-js";
  version = "0.2.0-alpha";

  src = fetchFromGitHub {
    owner = "steffest";
    repo = "DPaint-js";
    rev = "v${finalAttrs.version}";
    hash = "sha256-obC53PB7D13jUFhXKt34M4SgPZs0YPcVANv6o/16toU=";
  };

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -d "$out/share/dpaint-js" "$out/share/applications" "$out/bin"
    cp -rT . "$out/share/dpaint-js"

    install -Dm644 "$out/share/dpaint-js/_img/icon48.png" \
      "$out/share/icons/hicolor/48x48/apps/dpaint-js.png"
    install -Dm644 "$out/share/dpaint-js/_img/icon192.png" \
      "$out/share/icons/hicolor/192x192/apps/dpaint-js.png"
    install -Dm644 "$out/share/dpaint-js/_img/icon512.png" \
      "$out/share/icons/hicolor/512x512/apps/dpaint-js.png"

    cat > "$out/bin/dpaint-js" <<'EOF'
    #!${stdenvNoCC.shell}
    set -euo pipefail

    url="http://dpaint.localhost:18087/"

    for _ in $(seq 1 30); do
      if ${lib.getExe curl} -fsS "$url" >/dev/null 2>&1; then
        exec ${xdg-utils}/bin/xdg-open "$url"
      fi
      sleep 0.1
    done

    echo "DPaint.js local service is not reachable at $url" >&2
    exit 1
    EOF
    chmod +x "$out/bin/dpaint-js"

    cat > "$out/share/applications/dpaint-js.desktop" <<'EOF'
    [Desktop Entry]
    Name=DPaint.js
    GenericName=Pixel Art Editor
    Comment=Retro-focused web image editor inspired by Deluxe Paint
    Exec=dpaint-js
    Icon=dpaint-js
    Terminal=false
    Type=Application
    Categories=Graphics;2DGraphics;RasterGraphics;
    Keywords=pixel;paint;image;retro;amiga;
    EOF

    runHook postInstall
  '';

  meta = {
    description = "Retro-focused browser image editor inspired by Deluxe Paint";
    homepage = "https://github.com/steffest/DPaint-js";
    license = lib.licenses.mit;
    mainProgram = "dpaint-js";
    platforms = lib.platforms.linux;
  };
})
