{pkgs, ...}: {
  home.packages = with pkgs; [
    brave
    (chromium.override {
      commandLineArgs = [
        "--enable-features=AcceleratedVideoEncoder"
        "--ignore-gpu-blocklist"
        "--enable-zero-copy"
      ];
    })
  ];

  xdg.desktopEntries.firefox-esr = {
    name = "Firefox ESR";
    genericName = "Web Browser";
    exec = "firefox-esr %U";
    icon = "firefox-esr";
    terminal = false;
    type = "Application";
    categories = ["Network" "WebBrowser"];
    mimeType = [
      "text/html"
      "text/xml"
      "application/xhtml+xml"
      "application/vnd.mozilla.xul+xml"
      "x-scheme-handler/http"
      "x-scheme-handler/https"
    ];
    startupNotify = true;
    settings = {
      StartupWMClass = "firefox";
      Actions = "new-private-window;new-window;profile-manager-window";
    };
    actions = {
      new-private-window = {
        name = "New Private Window";
        exec = "firefox-esr --private-window %U";
      };
      new-window = {
        name = "New Window";
        exec = "firefox-esr --new-window %U";
      };
      profile-manager-window = {
        name = "Profile Manager";
        exec = "firefox-esr --ProfileManager";
      };
    };
  };
}
