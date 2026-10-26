{
  den,
  constructors,
  ...
}: {
  den.hosts.x86_64-linux.k3s = {
    aspect = den.aspects.host-k3s;
    instantiate = constructors.nixos {hostname = "k3s";};
  };
  den.aspects.host-k3s = {
    includes = with den.aspects; [proxmox-guest k3s];
    nixos = {
      lib,
      main-user,
      pkgs,
      ...
    }: let
      initializeDisk = pkgs.writeShellApplication {
        name = "k3s-initialize-disk";
        runtimeInputs = [pkgs.util-linux pkgs.e2fsprogs pkgs.diffutils pkgs.coreutils];
        text = builtins.readFile ../../../scripts/lab-initialize-disk.sh;
      };
    in {
      networking = {
        hostName = "k3s";
        useDHCP = lib.mkForce false;
        interfaces.ens18.ipv4.addresses = [
          {
            address = "192.168.2.106";
            prefixLength = 24;
          }
        ];
        defaultGateway = "192.168.2.1";
        nameservers = ["192.168.2.102"];
        firewall = {
          trustedInterfaces = ["cni0" "flannel.1"];
          extraCommands = ''
            iptables -w -A nixos-fw -s 192.168.2.111 -p tcp --dport 8080 -j nixos-fw-accept
            iptables -w -A nixos-fw -s 192.168.2.112 -p tcp --dport 6443 -j nixos-fw-accept
            iptables -w -A nixos-fw -s 10.0.1.0/24 -p tcp -m multiport --dports 22,6443 -j nixos-fw-accept
          '';
        };
      };
      fileSystems = {
        "/" = {
          device = "/dev/disk/by-label/nixos";
          fsType = "ext4";
        };
        "/var/lib/rancher/k3s" = {
          device = "/dev/disk/by-label/k3s-state";
          fsType = "ext4";
        };
      };
      boot = {
        loader.grub.device = lib.mkForce "/dev/vda";
        initrd.availableKernelModules = ["virtio_blk"];
        kernelParams = ["console=ttyS0"];
        kernel.sysctl."net.ipv4.ip_forward" = 1;
      };
      services.qemuGuest.enable = true;
      security.sudo.wheelNeedsPassword = false;
      users.users.${main-user} = {
        isNormalUser = true;
        extraGroups = ["wheel"];
        openssh.authorizedKeys.keys = [
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpqILWYPLnnke+4O3dAj61p8p+RghxZhTuP32TP6l07 david@nixos"
          "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJaTWrJGOvCf4dpAechU1ak3L+cylIrQtnjZsyMk/nSk david@nixos"
        ];
      };
      systemd.services.k3s-data-init = {
        requiredBy = ["var-lib-rancher-k3s.mount"];
        before = ["var-lib-rancher-k3s.mount"];
        after = ["systemd-udev-trigger.service"];
        unitConfig.DefaultDependencies = false;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          TimeoutStartSec = "10min";
        };
        path = [pkgs.coreutils];
        script = ''
          for attempt in $(seq 1 15); do
            if [ -b /dev/disk/by-id/virtio-k3s-state ]; then
              exec ${initializeDisk}/bin/k3s-initialize-disk /dev/disk/by-id/virtio-k3s-state k3s-state
            fi
            sleep 1
          done
          echo 'Missing designated k3s state disk' >&2
          exit 1
        '';
      };
      systemd.services.k3s = {
        requires = ["var-lib-rancher-k3s.mount"];
        after = ["var-lib-rancher-k3s.mount"];
        unitConfig.AssertPathIsMountPoint = "/var/lib/rancher/k3s";
      };
      system.stateVersion = "26.05";
    };
  };
}
