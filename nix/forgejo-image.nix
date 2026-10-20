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
    packages.forgejo-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      config = self.nixosConfigurations.forgejo.config;
      name = "forgejo";
      format = "qcow2";
      diskSize = 32 * 1024;
      partitionTableType = "legacy";
    };
  };
}
