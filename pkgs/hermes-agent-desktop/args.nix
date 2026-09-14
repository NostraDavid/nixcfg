{
  inputs,
  system,
  unstable,
  ...
}: let
  hermesAgent = inputs.hermes-agent.packages.${system}.default;
  hermesAgentSrc = inputs.hermes-agent.outPath;

  # Use nixpkgs' unpacked headers for the selected Electron version.
  # The upstream tarball hash can lag behind nixpkgs' Electron updates.
  desktopSource =
    builtins.replaceStrings [
      ''tar -xzf ''${electronHeaders} -C "$TMPDIR/electron-headers" --strip-components=1''
      "../apps/desktop/assets/icon.png"
      "../hermes_cli/linux_desktop_entry.py"
    ] [
      ''cp -r ''${electron.headers}/. "$TMPDIR/electron-headers"''
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
