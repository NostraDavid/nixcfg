{
  main-user,
  stable,
  ...
}: {
  services = {
    displayManager = {
      autoLogin = {
        enable = true;
        user = main-user;
      };
      defaultSession = "none+i3";
    };
    xserver = {
      displayManager.lightdm.enable = true;
      windowManager.i3 = {
        enable = true;
        extraPackages = [
          stable.dmenu
          stable.i3lock
          stable.i3status
        ];
      };
    };
  };

  security.pam.services.lightdm.kwallet.enable = true;
}
