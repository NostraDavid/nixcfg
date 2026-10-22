{stable, ...}: let
  # Firefox's NVIDIA VA-API driver fails to initialize inside the RDD sandbox.
  firefoxExec = "env -u MOZ_DRM_DEVICE -u MOZ_ENABLE_WAYLAND MOZ_X11_EGL=1 LIBVA_DRIVER_NAME=nvidia MOZ_DISABLE_RDD_SANDBOX=1 firefox-esr";
in {
  home.packages = [
    stable.lynx # Terminal web browser
    stable.w3m # Terminal web browser
    (stable.chromium.override {
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
    exec = "${firefoxExec} %U";
    icon = "firefox-esr";
    terminal = false;
    type = "Application";
    categories = [
      "Network"
      "WebBrowser"
    ];
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
        exec = "${firefoxExec} --private-window %U";
      };
      new-window = {
        name = "New Window";
        exec = "${firefoxExec} --new-window %U";
      };
      profile-manager-window = {
        name = "Profile Manager";
        exec = "${firefoxExec} --ProfileManager";
      };
    };
  };
}
