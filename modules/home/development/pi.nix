{
  inputs,
  stable,
  ...
}: let
  package = inputs.pi.packages.${stable.stdenv.hostPlatform.system}.coding-agent;
in {
  imports = [inputs.pi.homeModules.default];

  programs.pi.coding-agent = {
    enable = true;
    inherit package;
    settings = builtins.fromJSON (builtins.readFile ../../../dotfiles/pi-1.2.0/.pi/agent/settings.json);
    environment.HISTFILE.value = "/dev/null";
  };
}
