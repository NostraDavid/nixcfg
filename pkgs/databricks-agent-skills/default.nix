{
  lib,
  stdenvNoCC,
  src,
}: let
  pluginRoot = "${src}/plugins/databricks/copilot";
in
  stdenvNoCC.mkDerivation {
    pname = "databricks-agent-skills-copilot";
    version = "unstable-${src.lastModifiedDate}-${src.shortRev}";

    dontBuild = true;
    dontUnpack = true;

    installPhase = ''
      runHook preInstall

      mkdir -p "$out"
      cp -R "${pluginRoot}/hooks" "${pluginRoot}/skills" "$out/"
      cp "${pluginRoot}/hooks.json" "$out/hooks.json"
      cp "${pluginRoot}/.github/plugin/plugin.json" "$out/plugin.json"
      cp "${src}/LICENSE" "$out/LICENSE"

      substituteInPlace "$out/hooks.json" \
        --replace-fail 'python3 hooks/' '# Modified by NostraDavid/nixcfg: use VS Code plugin root.\npython3 ''${PLUGIN_ROOT}/hooks/' \
        --replace-fail 'python hooks/' '# Modified by NostraDavid/nixcfg: use VS Code plugin root.\npython ''${PLUGIN_ROOT}/hooks/'

      runHook postInstall
    '';

    meta = with lib; {
      description = "Databricks Agent Skills plugin for GitHub Copilot";
      homepage = "https://github.com/databricks/databricks-agent-skills";
      license = licenses.unfreeRedistributable;
      platforms = platforms.all;
    };
  }
