{self, ...}: let
  settings = import ../infra/proxmox-lab/settings.nix;
in
  {pkgs, ...}: {
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
  }
