{
  lib,
  main-user,
  stable,
  ...
}: {
  programs.niri.enable = true;

  services.xserver.enable = lib.mkForce false;

  services.greetd = {
    enable = true;
    settings.default_session = {
      command = "${stable.niri}/bin/niri-session";
      user = main-user;
    };
  };
}
