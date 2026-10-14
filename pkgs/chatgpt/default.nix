{
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  coreutils,
  cups,
  dbus,
  dpkg,
  expat,
  fetchurl,
  gdk-pixbuf,
  glib,
  gtk3,
  lib,
  libGL,
  libdrm,
  libnotify,
  libpulseaudio,
  libusb1,
  libX11,
  libxcb,
  libXcomposite,
  libXdamage,
  libXext,
  libXfixes,
  libxkbcommon,
  libXrandr,
  makeWrapper,
  mesa,
  nspr,
  nss,
  pango,
  python3,
  stdenv,
  systemd,
  vulkan-loader,
  xdg-utils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  version = "26.1007.71326";

  # The latest URL is mutable; pin the versioned pool artifact instead.
  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${finalAttrs.version}_amd64.deb";
    hash = "sha256-DgBrSTFxL1qQ1M0ElyxuC1M87c39srUZRtW5NnRx9VY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    dpkg
    makeWrapper
    python3
  ];

  buildInputs = [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    gdk-pixbuf
    glib
    gtk3
    libGL
    libdrm
    libnotify
    libpulseaudio
    libusb1
    libX11
    libxcb
    libXcomposite
    libXdamage
    libXext
    libXfixes
    libxkbcommon
    libXrandr
    mesa
    nspr
    nss
    pango
    systemd
    vulkan-loader
    xdg-utils
  ];
  autoPatchelfIgnoreMissingDeps = [
    "libQt5Core.so.5"
    "libQt5Gui.so.5"
    "libQt5Widgets.so.5"
    "libQt6Core.so.6"
    "libQt6Gui.so.6"
    "libQt6Widgets.so.6"
    "libc.musl-x86_64.so.1"
  ];

  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x "$src" .
    runHook postUnpack
  '';

  # autoPatchelf moves PT_INTERP beyond detect-libc's 2 KiB scan. Its
  # process.report fallback trips Electron's CFI, so use the glibc watcher.
  # Keep the replacement length unchanged to preserve ASAR offsets.
  postPatch = ''
    grep -aFq 'const family = familySync();' usr/lib/chatgpt/resources/app.asar
    sed -i "s|const family = familySync();|const family = 'glibc'     ;|" usr/lib/chatgpt/resources/app.asar

    # Node's recursive copy preserves the Nix store's read-only mode. The
    # local Work executor must rewrite its copied MCP configuration.
    python3 - <<'PY'
    import mmap
    import re

    with open("usr/lib/chatgpt/resources/app.asar", "r+b") as file, mmap.mmap(file.fileno(), 0) as archive:
        initializer = re.search(rb"async function [\w$]+\(\{executorPluginRoot:", archive)
        assert initializer is not None, "executor plugin initializer not found"
        start = initializer.start()
        end = archive.find(b"async function ", initializer.end())
        assert end > start, "executor plugin initializer boundary not found"
        before = archive[start:end]
        after, count = re.subn(
            rb"(let n=await [\w$]+\(\{useWsl:!1,resourcesPath:t\}\));",
            rb"\1,f=x.default,p=C.default;",
            before,
        )
        assert count == 1, "executor definition lookup changed"
        after = after.replace(
            b"process.platform!==`win32`&&(n.command=C.default.join(e,C.default.relative(n.cwd,n.command)))",
            b"n.command=C.default.join(e,C.default.relative(n.cwd,n.command))",
        ).replace(b"x.default.", b"f.").replace(b"C.default.", b"p.").replace(
            b"await f.writeFile(p.join(e,`.mcp.json`),",
            b"await f.chmod(p.join(e,`.mcp.json`),384),await f.writeFile(p.join(e,`.mcp.json`),",
        )
        assert b"await f.chmod(" in after, "executor permissions patch did not apply"
        assert len(after) <= len(before), "executor permissions patch changes ASAR offsets"
        archive[start:end] = after.ljust(len(before))

        # Marketplace materialization edits copied plugin metadata and removes
        # disabled skills. Node's cp preserves immutable Nix-store permissions.
        helper = re.search(
            rb"async function ([\w$]+)\(e,t\)\{if\([\w$]+\.default\.platform===`darwin`\)\{await ([\w$]+)\(`/usr/bin/ditto`",
            archive,
        )
        assert helper is not None, "marketplace copy helper not found"
        start = helper.start()
        end = archive.find(b"async function ", helper.end())
        assert end > start, "marketplace copy helper boundary not found"
        before = archive[start:end]
        assert b"await x.default.cp(e,t," in before, "marketplace copy helper changed"
        name, runner = helper.groups()
        after = b'async function ' + name + b'(e,t){await ' + runner + b'(`${coreutils}/bin/cp`,[`-R`,`--`,e+`/.`,t]);await ' + runner + b'(`${coreutils}/bin/chmod`,[`-R`,`u+w`,`--`,t])}'
        assert len(after) <= len(before), "marketplace permissions patch changes ASAR offsets"
        archive[start:end] = after.ljust(len(before))
    PY
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p "$out"
    cp -R --no-preserve=ownership usr/. "$out/"
    runHook postInstall
  '';

  # Electron dlopens libGL, so autoPatchelfHook cannot discover this dependency.
  postFixup = ''
    wrapProgram "$out/lib/chatgpt/codex-launcher" \
      --prefix LD_LIBRARY_PATH : "${libGL}/lib"
  '';

  meta = {
    description = "ChatGPT desktop application for Linux";
    homepage = "https://chatgpt.com/download/";
    license = lib.licenses.unfree;
    mainProgram = "chatgpt";
    platforms = ["x86_64-linux"];
    sourceProvenance = with lib.sourceTypes; [binaryNativeCode];
  };
})
