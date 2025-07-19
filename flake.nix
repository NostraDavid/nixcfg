{
  description = "NixOS configuration for Odin";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs: {
    nixosConfigurations."nixos" = inputs.nixpkgs.lib.nixosSystem {
      modules = [
        {nix.settings.experimental-features = ["nix-command" "flakes"];}
        ./configuration.nix
      ];
    };
  };
}
