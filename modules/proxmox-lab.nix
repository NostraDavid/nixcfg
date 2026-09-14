{
  self,
  inputs,
  ...
}: let
  settings = import ../infra/proxmox-lab/settings.nix;
in {
  flake.modules.nixos.proxmox-lab-host = {pkgs, ...}: {
    boot.extraModprobeConfig = "options kvm_amd nested=1";
    virtualisation.libvirtd = {
      enable = true;
      qemu.runAsRoot = false;
      onBoot = "ignore";
      onShutdown = "shutdown";
      shutdownTimeout = 300;
    };
    users.users.david.extraGroups = ["libvirtd"];
    systemd.tmpfiles.rules = [
      "d /var/lib/proxmox-lab 2770 qemu-libvirtd libvirtd -"
      "d /var/lib/proxmox-lab/current 2770 qemu-libvirtd libvirtd -"
      "d /var/lib/proxmox-lab/archive 2770 qemu-libvirtd libvirtd -"
    ];
    environment.systemPackages = [pkgs.virt-manager self.packages.x86_64-linux.proxmox-lab];
    networking.networkmanager.ensureProfiles.profiles = {
      lab-bridge = {
        connection = {
          id = "lab-bridge";
          type = "bridge";
          interface-name = settings.bridge;
          autoconnect = true;
          autoconnect-priority = 100;
        };
        bridge = {
          stp = false;
          mac-address = "34:5a:60:50:eb:f5";
        };
        ipv4 = {
          method = "auto";
          dhcp-client-id = "01:34:5a:60:50:eb:f5";
          route1 = "192.168.2.100/32,10.0.1.1";
        };
        ipv6.method = "auto";
      };
      lab-uplink = {
        connection = {
          id = "lab-uplink";
          type = "ethernet";
          interface-name = settings.interface;
          master = settings.bridge;
          slave-type = "bridge";
          autoconnect = true;
          autoconnect-priority = 100;
        };
      };
    };
  };

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
        exec python3 ${../cmd/proxmox-lab.py} "$@"
      '';
    };
  };
}
