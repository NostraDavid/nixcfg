{
  alsa-lib,
  _7zz,
  autoPatchelfHook,
  dpkg,
  fetchurl,
  gcc,
  lib,
  libxcb,
  libxkbcommon,
  makeWrapper,
  stdenvNoCC,
  vulkan-loader,
  wayland,
  wl-clipboard,
  xclip,
}: let
  assets = {
    x86_64-linux = {
      target = "x86_64-unknown-linux-gnu.deb";
      hash = "sha256-mUCjodktB2xTQm55o4GqUHHjtoD4Otqy7lDP/437tio=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-gnu.deb";
      hash = "sha256-aLMycWtGknNWjjPAZqPj0f8dOUy6ahElJuEpVbRdXWI=";
    };
    aarch64-darwin = {
      target = "universal-apple-darwin.dmg";
      hash = "sha256-Ksi5jKCYC+5SYe72G19a1gTNkjTqwj2ZG0rswUr6VHw=";
    };
    x86_64-darwin = {
      target = "universal-apple-darwin.dmg";
      hash = "sha256-Ksi5jKCYC+5SYe72G19a1gTNkjTqwj2ZG0rswUr6VHw=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system};
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "herdr-gpui";
    version = "20261028.1";
    src = fetchurl {
      url = "https://github.com/penso/herdr-gpui/releases/download/v${finalAttrs.version}/Herdr-${finalAttrs.version}-${asset.target}";
      inherit (asset) hash;
    };
    nativeBuildInputs =
      if stdenvNoCC.hostPlatform.isDarwin
      then [_7zz]
      else [autoPatchelfHook dpkg makeWrapper];
    buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [alsa-lib libxcb libxkbcommon gcc.cc.lib];
    runtimeDependencies = lib.optionals stdenvNoCC.hostPlatform.isLinux [vulkan-loader wayland];
    dontFixup = stdenvNoCC.hostPlatform.isDarwin;
    unpackPhase = ''
      runHook preUnpack
      ${
        if stdenvNoCC.hostPlatform.isDarwin
        then ''7zz x "$src" -y''
        else ''dpkg-deb -x "$src" .''
      }
      runHook postUnpack
    '';
    installPhase = ''
      runHook preInstall
      ${
        if stdenvNoCC.hostPlatform.isDarwin
        then ''
          mkdir -p "$out/Applications" "$out/bin"
          cp -R Herdr.app "$out/Applications/"
          ln -s "$out/Applications/Herdr.app/Contents/MacOS/Herdr" "$out/bin/herdr-gpui"
        ''
        else ''
          mkdir -p "$out"
          cp -R --no-preserve=ownership usr/. "$out/"
        ''
      }
      runHook postInstall
    '';
    postFixup = lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      wrapProgram "$out/bin/herdr-gpui" --prefix PATH : ${lib.makeBinPath [wl-clipboard xclip]}
    '';
    doInstallCheck = stdenvNoCC.hostPlatform.isLinux;
    installCheckPhase = lib.optionalString stdenvNoCC.hostPlatform.isLinux ''
      patchelf --print-rpath "$out/bin/.herdr-gpui-wrapped" | grep -F '${vulkan-loader}/lib'
      patchelf --print-rpath "$out/bin/.herdr-gpui-wrapped" | grep -F '${wayland}/lib'
    '';
    meta = {
      description = "Native client for the Herdr daemon";
      homepage = "https://github.com/penso/herdr-gpui";
      license = lib.licenses.asl20;
      mainProgram = "herdr-gpui";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
