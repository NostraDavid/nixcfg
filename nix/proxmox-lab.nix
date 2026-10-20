{
  self,
  inputs,
  ...
}: let
  settings = import ../infra/proxmox-lab/settings.nix;
in {
  perSystem = {
    pkgs,
    lib,
    ...
  }: {
    packages.forgejo-lab-image = import "${inputs.nixpkgs}/nixos/lib/make-disk-image.nix" {
      inherit pkgs lib;
      config = self.nixosConfigurations.forgejo-lab.config;
      name = "forgejo-lab";
      format = "qcow2";
      diskSize = settings.forgejo.systemDiskGiB * 1024;
      partitionTableType = "legacy";
    };
    packages.proxmox-lab = pkgs.writeShellApplication {
      name = "proxmox-lab";
      runtimeInputs = with pkgs; [
        python3
        proxmox-auto-install-assistant
        libisoburn
        qemu_kvm
        libvirt
        iputils
        iproute2
        jq
        curl
        openssl
        openssh
        coreutils
        acl
        util-linux
        e2fsprogs
        diffutils
        gnugrep
        gnutar
        zstd
        opentofu
        networkmanager
        systemd
        nixos-rebuild
        git
      ];
      text = ''
        export PROXMOX_LAB_CONFIG=${pkgs.writeText "proxmox-lab.json" (builtins.toJSON settings)}
        exec python3 ${../scripts/proxmox-lab.py} "$@"
      '';
    };
  };
}
