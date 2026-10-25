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
    packages.openbao-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      config = self.nixosConfigurations.openbao.config;
      name = "openbao";
      format = "qcow2";
      diskSize = 16 * 1024;
      partitionTableType = "legacy";
    };
    checks.openbao =
      pkgs.runCommand "openbao-integration-check" {
        nativeBuildInputs = [pkgs.python3 pkgs.openbao pkgs.openldap pkgs.openssl pkgs.age];
      } ''
        export HOME="$TMPDIR/home"
        export PATH="${pkgs.openldap}/libexec:$PATH"
        mkdir -p "$HOME"
        python3 ${../checks/test-openbao.py} ${../scripts/openbao.py}
        touch "$out"
      '';
    checks.openbao-image =
      pkgs.runCommand "openbao-image-check" {
        nativeBuildInputs = [pkgs.python3 pkgs.qemu pkgs.age pkgs.openssl];
      } ''
        python3 ${../checks/test-openbao-image.py} ${self.packages.${pkgs.stdenv.hostPlatform.system}.openbao-image}/nixos.qcow2
        touch "$out"
      '';
  };
}
