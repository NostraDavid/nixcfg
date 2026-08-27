{
  inputs,
  system,
  unstable,
  ...
}: let
  hermesAgent = inputs.hermes-agent.packages.${system}.default;
  hermesAgentSrc = inputs.hermes-agent.outPath;

  # The upstream desktop package currently pins a stale Electron header hash.
  # Re-evaluate that package from the locked source with the artifact's
  # current content hash until upstream publishes the correction.
  desktopSource =
    builtins.replaceStrings [
      "sha256-f8bSbLRmtbP93CJAvEBs+sHWDZ1xP2bcpLhC1EnOmZU="
      "../apps/desktop/assets/icon.png"
      "../hermes_cli/linux_desktop_entry.py"
    ] [
      "sha256-CyzcARd1+GhWr8ED7HBYW2MYD+tgetqZFMkaivaGvw0="
      "${hermesAgentSrc}/apps/desktop/assets/icon.png"
      "${hermesAgentSrc}/hermes_cli/linux_desktop_entry.py"
    ] (builtins.readFile "${hermesAgentSrc}/nix/desktop.nix");
in {
  hermesAgentDesktop =
    unstable.callPackage
    (builtins.toFile "hermes-desktop.nix" desktopSource)
    {
      inherit (hermesAgent) hermesNpmLib;
      inherit hermesAgent;
    };
  inherit hermesAgentSrc;
}
