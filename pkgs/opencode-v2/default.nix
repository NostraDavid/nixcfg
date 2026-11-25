{
  autoPatchelfHook,
  fetchurl,
  lib,
  libxcb,
  makeWrapper,
  ripgrep,
  stdenv,
  stdenvNoCC,
}: let
  assets = {
    x86_64-linux = {
      target = "linux-x64-baseline";
      hash = "sha512-hYF+w2CQU/Jx4Px2VNxHrfUybR6xze1FeOCmPXXsPWXWkk0BILJkxI0fQVA1FzlGPy6avHWJzzJ1fCf9wwkupw==";
    };
    aarch64-linux = {
      target = "linux-arm64";
      hash = "sha512-olNKfoAuHaDtHrWrlqxh2RPSonSfAZPGJlru7tMNeNTlHyLSrTbDe/+HJ6vdYRp7g4yKLSQ8SG264U/IC7Pgtw==";
    };
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha512-r6PIZl5wqFxVYfVFjm2JK4uf1a3YT7FMEVTODJF/1hKe6wBdK7THzbAM1SSyuRuMnSkDb9+dd8xNOk9zQK6trg==";
    };
    x86_64-darwin = {
      target = "darwin-x64-baseline";
      hash = "sha512-VdX18DyzRYIlJExWwHZxlw5fwlWeyZT0aVBnwgqz1fReq6nUPl7UbRtkOjS3nJnCbkUXlUkOIqCttvVp05dlJQ==";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported OpenCode v2 platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "opencode-v2";
    version = "2.4.1";
    src = fetchurl {
      url = "https://registry.npmjs.org/@opencode/cli-${asset.target}/-/cli-${asset.target}-${finalAttrs.version}.tgz";
      inherit (asset) hash;
    };

    dontBuild = true;
    # Bun embeds its application payload in the executable.
    dontStrip = true;
    nativeBuildInputs = [makeWrapper] ++ lib.optionals stdenvNoCC.hostPlatform.isLinux [autoPatchelfHook];
    buildInputs = lib.optionals stdenvNoCC.hostPlatform.isLinux [stdenv.cc.cc.lib];
    installPhase = ''
      runHook preInstall
      install -Dm755 bin/opencode "$out/bin/opencode"
      wrapProgram "$out/bin/opencode" \
        --suffix PATH : ${lib.makeBinPath [ripgrep]} \
        ${lib.optionalString stdenvNoCC.hostPlatform.isLinux "--suffix LD_LIBRARY_PATH : ${lib.makeLibraryPath [libxcb]}"} \
        --set OPENCODE_DISABLE_AUTOUPDATE true \
        --run '
          # Preserve the database choice made by older nixpkgs installations.
          opencode_data_home="''${XDG_DATA_HOME:-$HOME/.local/share}/opencode"
          if [ -z "''${OPENCODE_DB:-}" ] \
            && [ -z "''${NIXPKGS_OPENCODE_DISABLE_LEGACY_DB_WORKAROUND:-}" ] \
            && [ -e "$opencode_data_home/opencode-stable.db" ] \
            && [ ! -e "$opencode_data_home/opencode.db" ]; then
            export OPENCODE_DB="opencode-stable.db"
          fi
        '
      runHook postInstall
    '';

    doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
    installCheckPhase = ''
      runHook preInstallCheck
      export XDG_CONFIG_HOME="$TMPDIR/config"
      export XDG_DATA_HOME="$TMPDIR/data"
      export XDG_STATE_HOME="$TMPDIR/state"
      export XDG_CACHE_HOME="$TMPDIR/cache"
      "$out/bin/opencode" --version | grep -F '${finalAttrs.version}'
      "$out/bin/opencode" --help > /dev/null
      runHook postInstallCheck
    '';

    meta = {
      description = "OpenCode v2 terminal client and coding-agent service";
      homepage = "https://opencode.ai/v2/docs";
      license = lib.licenses.mit;
      mainProgram = "opencode";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  })
