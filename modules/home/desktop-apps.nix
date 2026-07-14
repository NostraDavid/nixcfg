{pkgs, ...}: let
  geeqieDesktop = "org.geeqie.Geeqie.desktop";
in {
  home.packages = with pkgs; [
    fsearch
    geeqie
    ghostty
    gimp3
    gparted
    hardinfo2
    hermes-agent-desktop
    kdePackages.kclock
    keepassxc
    speedcrunch
    synology-drive-client
    wireguard-tools
  ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "image/avif" = geeqieDesktop;
      "image/bmp" = geeqieDesktop;
      "image/gif" = geeqieDesktop;
      "image/heic" = geeqieDesktop;
      "image/heif" = geeqieDesktop;
      "image/jpeg" = geeqieDesktop;
      "image/png" = geeqieDesktop;
      "image/svg" = geeqieDesktop;
      "image/svg+xml" = geeqieDesktop;
      "image/tiff" = geeqieDesktop;
      "image/webp" = geeqieDesktop;
      "image/x-bmp" = geeqieDesktop;
      "image/x-ico" = geeqieDesktop;
      "image/x-icon" = geeqieDesktop;
      "image/x-MS-bmp" = geeqieDesktop;
      "image/x-png" = geeqieDesktop;
      "image/x-portable-anymap" = geeqieDesktop;
      "image/x-portable-bitmap" = geeqieDesktop;
      "image/x-portable-graymap" = geeqieDesktop;
      "image/x-portable-pixmap" = geeqieDesktop;
      "image/x-tga" = geeqieDesktop;
      "image/x-xbitmap" = geeqieDesktop;
      "image/x-xpixmap" = geeqieDesktop;
      "image/xpm" = geeqieDesktop;
    };
  };
}
