{
  lib,
  buildNpmPackage,
  fetchurl,
  makeDesktopItem,
  nix-update-script,
  autoPatchelfHook,
  patchelfUnstable,
  stdenv,
  openssl,
  ncurses,
  zlib,
  postgresql_18,
  python3,
}: let
  platforms = {
    x86_64-linux = "linux-x64";
    aarch64-linux = "linux-arm64";
    x86_64-darwin = "darwin-x64";
    aarch64-darwin = "darwin-arm64";
  };
  platform = platforms.${stdenv.hostPlatform.system};
  desktopItem = makeDesktopItem {
    name = "paperclip";
    desktopName = "Paperclip";
    comment = "Start the local Paperclip server and open its dashboard";
    exec = "env PAPERCLIP_OPEN_ON_LISTEN=true paperclipai run";
    icon = "paperclip";
    terminal = true;
    categories = ["Development"];
  };
in
  buildNpmPackage (finalAttrs: {
    pname = "paperclip";
    version = "2026.1012.0";

    src = fetchurl {
      url = "https://registry.npmjs.org/paperclipai/-/paperclipai-${finalAttrs.version}.tgz";
      hash = "sha256-zCMxBYvZPLbU7hjNKbz2PAYh/E9u8MfPeMUkPL6cUK4=";
    };
    sourceRoot = "package";

    postPatch = ''
      # uuid 11 retains CommonJS support and fixes CVE-2026-41907.
      substituteInPlace package.json --replace-fail '"dependencies": {' \
        '"overrides": {"svix": {"uuid": "11.1.1"}}, "dependencies": {'
      cp ${./package-lock.json} package-lock.json
    '';

    npmDepsHash = "sha256-PP8CvwB+Ul+jG/1ZPhlLnneK/do+lq32pPPiLV57518=";
    npmFlags = ["--omit=dev"];
    npmRebuildFlags = ["--ignore-scripts"];
    dontNpmBuild = true;

    nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = [openssl zlib ncurses] ++ lib.optionals stdenv.hostPlatform.isLinux [stdenv.cc.cc.lib];

    # Patchelf 0.15 corrupts the bundled libvips; 0.18 preserves its ELF layout.
    preFixup = lib.optionalString stdenv.hostPlatform.isLinux ''
      export PATH="${patchelfUnstable}/bin:$PATH"
    '';

    # The bundled PostgreSQL executables expect an FHS host. Use Nix's PostgreSQL.
    postInstall = ''
      native="$out/lib/node_modules/paperclipai/node_modules/@embedded-postgres/${platform}/native"
      rm -rf "$native"
      mkdir -p "$native"
      ln -s ${lib.getBin postgresql_18}/bin "$native/bin"
      ln -s ${postgresql_18}/lib "$native/lib"
      ln -s ${postgresql_18}/share "$native/share"
      # Embedded clients use TCP; nixpkgs' default Unix socket directory may not exist.
      substituteInPlace \
        "$out/lib/node_modules/paperclipai/dist/index.js" \
        "$out/lib/node_modules/paperclipai/node_modules/embedded-postgres/dist/index.js" \
        --replace-fail 'postgresFlags: []' 'postgresFlags: ["-c", "unix_socket_directories="]'
      mkdir -p "$out/share"
      cp -r ${desktopItem}/share/applications "$out/share/"
      install -Dm644 \
        "$out/lib/node_modules/paperclipai/node_modules/@paperclipai/server/ui-dist/favicon.svg" \
        "$out/share/icons/hicolor/scalable/apps/paperclip.svg"
    '';

    doInstallCheck = true;
    nativeInstallCheckInputs = [python3];
    installCheckPhase = ''
      runHook preInstallCheck
      HOME="$TMPDIR" "$out/bin/paperclipai" --version | grep -F '${finalAttrs.version}'
      HOME="$TMPDIR" "$out/bin/paperclipai" --help | grep -F 'onboard'
      test -s "$out/share/icons/hicolor/scalable/apps/paperclip.svg"
      test -f "$out/share/applications/paperclip.desktop"
      node ${./check-uuid.cjs} "$out/lib/node_modules/paperclipai"
      python3 ${./check-server.py} "$out/bin/paperclipai"
      runHook postInstallCheck
    '';

    passthru.updateScript = nix-update-script {extraArgs = ["--generate-lockfile"];};

    meta = {
      description = "Orchestrate AI agents with a local server and web dashboard";
      homepage = "https://github.com/paperclipai/paperclip";
      changelog = "https://github.com/paperclipai/paperclip/releases/tag/v${finalAttrs.version}";
      license = lib.licenses.mit;
      mainProgram = "paperclipai";
      platforms = builtins.attrNames platforms;
    };
  })
