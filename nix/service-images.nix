{
  self,
  inputs,
  ...
}: {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    packages = {
      k3s-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
        inherit pkgs lib;
        config = self.nixosConfigurations.k3s.config;
        name = "k3s";
        format = "qcow2";
        diskSize = 32 * 1024;
        partitionTableType = "legacy";
      };
      certs-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
        inherit pkgs lib;
        config = self.nixosConfigurations.certs.config;
        name = "certs";
        format = "qcow2";
        diskSize = 16 * 1024;
        partitionTableType = "legacy";
      };
      homepage-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
        inherit pkgs lib;
        config = self.nixosConfigurations.homepage.config;
        name = "homepage";
        format = "qcow2";
        diskSize = 16 * 1024;
        partitionTableType = "legacy";
      };
    };
  };
}
