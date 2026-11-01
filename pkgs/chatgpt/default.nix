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
  nodejs,
  pango,
  python3,
  stdenv,
  systemd,
  vulkan-loader,
  xdg-utils,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "chatgpt";
  version = "26.1027.51404";

  # The latest URL is mutable; pin the versioned pool artifact instead.
  src = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${finalAttrs.version}_amd64.deb";
    hash = "sha256-RvHiLQKGmP6e2u/VhHrs4HxFCaMNNwnhBCIHGdjBKCI=";
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
        # Recent bundles call module factories and use different local names.
        factory = re.search(rb'await ([\w$]+)\(\)\.cp\(([\w$]+)\.cwd,([\w$]+),', before)
        if factory:
            fs_module, definition, dest = factory.groups()
            path_match = re.search(rb'([\w$]+)\(\)\.join\(' + dest + rb',\1\(\)\.relative\(' + definition + rb'\.cwd,', before)
            assert path_match is not None, "executor path factory not found"
            path_module = path_match.group(1)
            after = before.replace(fs_module + b"().", b"f.").replace(path_module + b"().", b"p.")
            after, count = re.subn(rb'(let ' + definition + rb'=await [\w$]+\([^;]+\));', rb'\1,f=' + fs_module + b'(),p=' + path_module + b'();', after, count=1)
            assert count == 1, "executor definition lookup changed"
            guard = b'"win32"!==process.platform&&('
            assert after.count(guard) == 1, "executor platform guard changed"
            after = after.replace(guard, b'(', 1)
            write = b'await f.writeFile(p.join(' + dest + b',".mcp.json"),'
            assert after.count(write) == 1, "executor configuration write changed"
            after = after.replace(write, b'await f.chmod(p.join(' + dest + b',".mcp.json"),384),' + write, 1)
            config = b'p.join(' + dest + b',".mcp.json")'
            assert after.count(config) == 2 and not re.search(rb'\bc\b', before), "executor config alias collision"
            after = after.replace(config, b'c').replace(b'p=' + path_module + b'();', b'p=' + path_module + b'(),c=' + config + b';', 1)
        else:
            fs_alias = re.search(rb"await ([\w$]+)\.default\.cp\(n\.cwd,e,", before)
            path_alias = re.search(rb"n\.command=([\w$]+)\.default\.join\(e,", before)
            assert fs_alias is not None and path_alias is not None, "executor module aliases not found"
            fs_module, path_module = fs_alias.group(1), path_alias.group(1)
            after, count = re.subn(
            rb"(let n=await [\w$]+\(\{useWsl:!1,resourcesPath:t\}\));",
            rb"\1,f=" + fs_module + b".default,p=" + path_module + b".default;",
            before,
        )
            assert count == 1, "executor definition lookup changed"
            after = after.replace(
            b"process.platform!==`win32`&&(n.command=" + path_module + b".default.join(e," + path_module + b".default.relative(n.cwd,n.command)))",
            b"n.command=" + path_module + b".default.join(e," + path_module + b".default.relative(n.cwd,n.command))",
        ).replace(fs_module + b".default.", b"f.").replace(path_module + b".default.", b"p.").replace(
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
        if helper is None:
            helper = re.search(rb'async function ([\w$]+)\(e,t\)\{if\("darwin"===[\w$]+\(\)\.platform\)return void await ([\w$]+)\("/usr/bin/ditto"', archive)
        assert helper is not None, "marketplace copy helper not found"
        start = helper.start()
        end = archive.find(b"async function ", helper.end())
        assert end > start, "marketplace copy helper boundary not found"
        before = archive[start:end]
        assert re.search(rb"await [\w$]+(?:\.default|\(\))\.cp\(e,t,", before), "marketplace copy helper changed"
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

  doInstallCheck = true;
  nativeInstallCheckInputs = [nodejs];
  installCheckPhase = ''
    runHook preInstallCheck
    node ${./check-executor.cjs} "$out/lib/chatgpt/resources/app.asar"
    runHook postInstallCheck
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
