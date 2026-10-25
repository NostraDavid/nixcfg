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
    packages.certs-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      config = self.nixosConfigurations.certs.config;
      name = "certs";
      format = "qcow2";
      diskSize = 16 * 1024;
      partitionTableType = "legacy";
    };
    packages.homepage-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      config = self.nixosConfigurations.homepage.config;
      name = "homepage";
      format = "qcow2";
      diskSize = 16 * 1024;
      partitionTableType = "legacy";
    };
  };
}
