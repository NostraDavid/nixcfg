{
  autoPatchelfHook,
  fetchurl,
  lib,
  makeWrapper,
  ripgrep,
  stdenv,
  stdenvNoCC,
}: let
  assets = {
    x86_64-linux = {
      target = "linux-x64-baseline";
      hash = "sha512-0/H4wRDAW4hA5IWN440XwDrRATbvT3cno+UUsqFynTu0TeGXNADjK2AZfvhNTfyJaVyCa+v7VhB+r7ghuMa5EQ==";
    };
    aarch64-linux = {
      target = "linux-arm64";
      hash = "sha512-drw0LWMG0niaE94ePXm1h7qjFBZZRcSZD3gact3hx3OYPXesp7xrOt0bn3sicYNUN6fojERrDKR6jYrXmZX+rA==";
    };
    aarch64-darwin = {
      target = "darwin-arm64";
      hash = "sha512-QwjyvovTdT0gFi5rxUyPVlYePIe3ELduR9olu+KJWe089XVIDOTMhxylBe/ZGIpvoXHYo6bp2NskIiqCFAEXsw==";
    };
    x86_64-darwin = {
      target = "darwin-x64-baseline";
      hash = "sha512-htb+MYexlbFPc/da+jXePmclbXuMMX4m8kSIe24wbgy/npTC8wv1VHj0QTDt9YttTnnas+Yr1kNmJ7j/86yt+Q==";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported OpenCode v2 platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "opencode-v2";
    version = "2.1.4";
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
