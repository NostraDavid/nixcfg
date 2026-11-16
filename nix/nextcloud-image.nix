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
    packages.nextcloud-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      config = self.nixosConfigurations.nextcloud.config;
      name = "nextcloud";
      format = "qcow2";
      diskSize = 32 * 1024;
      partitionTableType = "legacy";
    };
    checks.nextcloud-ldap = pkgs.testers.runNixOSTest (import ../checks/nextcloud-ldap.nix {
      inherit pkgs;
      nextcloudModule = self.modules.nixos.nextcloud;
    });
  };
}
