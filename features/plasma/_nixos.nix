{main-user, ...}: {
  services = {
    displayManager = {
      autoLogin = {
        enable = true;
        user = main-user;
      };
      sddm.enable = true;
    };
    desktopManager.plasma6.enable = true;
  };
}
