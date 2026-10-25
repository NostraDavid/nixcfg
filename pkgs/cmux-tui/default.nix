{
  fetchurl,
  lib,
  stdenvNoCC,
}: let
  rev = "316d139feaf89d9ab7c99dc9cffdce59309bef93";
  assets = {
    aarch64-darwin = {
      target = "aarch64-apple-darwin";
      hash = "sha256-5qntRii7OIMAcz8KZeNcftYMveeEomi3xMHS24uEys0=";
    };
    x86_64-darwin = {
      target = "x86_64-apple-darwin";
      hash = "sha256-RmqPMLpme6fjCOpXFygCtiXJ4wuKG/6UXmCujPzmoko=";
    };
    x86_64-linux = {
      target = "x86_64-unknown-linux-musl";
      hash = "sha256-X3f0rD0DEy5MNAVy5S8Avm9PKsP83VLDSXytPr7mvDw=";
    };
    aarch64-linux = {
      target = "aarch64-unknown-linux-musl";
      hash = "sha256-jToNHlM2F+ZrIKromf7d1yf78tE5+R9pe1hrbfCBUWo=";
    };
  };
  asset = assets.${stdenvNoCC.hostPlatform.system} or (throw "Unsupported cmux TUI platform: ${stdenvNoCC.hostPlatform.system}");
in
  stdenvNoCC.mkDerivation {
    pname = "cmux-tui";
    version = "0.1.0-unstable-2026-10-22";
    src = fetchurl {
      url = "https://files.cmux.com/cmux-tui/${rev}/cmux-tui-${asset.target}";
      inherit (asset) hash;
    };

    dontUnpack = true;
    dontBuild = true;
    # Preserve the upstream Mach-O signature.
    dontStrip = stdenvNoCC.hostPlatform.isDarwin;
    installPhase = ''
      runHook preInstall
      install -Dm755 "$src" "$out/bin/cmux"
      runHook postInstall
    '';

    doInstallCheck = stdenvNoCC.buildPlatform.canExecute stdenvNoCC.hostPlatform;
    installCheckPhase = ''
      runHook preInstallCheck
      "$out/bin/cmux" --version | grep -F '${rev}'
      "$out/bin/cmux" --help > /dev/null
      runHook postInstallCheck
    '';

    meta = {
      description = "Terminal multiplexer with workspaces, split panes and a control socket";
      homepage = "https://cmux.com/docs/tui";
      license = lib.licenses.mit;
      mainProgram = "cmux";
      platforms = builtins.attrNames assets;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  }
