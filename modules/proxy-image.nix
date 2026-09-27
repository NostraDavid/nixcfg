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
    packages.proxy-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      config = self.nixosConfigurations.proxy.config;
      name = "proxy";
      format = "qcow2";
      diskSize = 16 * 1024;
      partitionTableType = "legacy";
    };
  };
}
