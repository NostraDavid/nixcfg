{
  lib,
  stable,
  ...
}: let
  inline = {
    showDesktop = stable.writeShellScriptBin "i3-show-desktop" ''
      current_workspace="$(${stable.i3}/bin/i3-msg -t get_workspaces | ${lib.getExe stable.jq} -r '.[] | select(.focused).name')"

      if [ "$current_workspace" = "__desktop" ]; then
        exec ${stable.i3}/bin/i3-msg workspace back_and_forth
      else
        exec ${stable.i3}/bin/i3-msg 'workspace __desktop'
      fi
    '';
  };
in {
  home.packages = [
    inline.showDesktop
    stable.brightnessctl
    stable.dmenu
    stable.i3lock
    stable.i3status
    stable.kdePackages.dolphin
    stable.kdePackages.kwallet
    stable.kdePackages.spectacle
    stable.networkmanagerapplet
    stable.pavucontrol
  ];
}
