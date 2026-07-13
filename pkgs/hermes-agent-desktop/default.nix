{
  lib,
  makeDesktopItem,
  symlinkJoin,
  hermesAgentDesktop,
  hermesAgentSrc,
}:
symlinkJoin {
  inherit (hermesAgentDesktop) version;
  pname = "hermes-agent-desktop";
  name = "hermes-agent-desktop-${hermesAgentDesktop.version}";

  paths = [
    hermesAgentDesktop
    (makeDesktopItem {
      name = "hermes-agent";
      desktopName = "Hermes";
      genericName = "AI Agent";
      comment = "Native desktop shell for Hermes Agent";
      exec = "hermes-desktop %U";
      icon = "hermes-agent";
      terminal = false;
      categories = ["Utility"];
      mimeTypes = ["x-scheme-handler/hermes"];
      startupWMClass = "Hermes";
    })
  ];

  postBuild = ''
    install -Dm644 ${hermesAgentSrc}/apps/desktop/assets/icon.png \
      "$out/share/icons/hicolor/1024x1024/apps/hermes-agent.png"
  '';

  meta =
    hermesAgentDesktop.meta
    // {
      homepage = "https://hermes-agent.nousresearch.com/";
      mainProgram = "hermes-desktop";
      platforms = lib.platforms.linux;
    };
}
