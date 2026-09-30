{
  flake.modules.homeManager = {
    cloud = ./home/development/cloud.nix;
    mediaTools = ./home/workstation/media-tools.nix;
    workstation = ./home/workstation;
  };
}
