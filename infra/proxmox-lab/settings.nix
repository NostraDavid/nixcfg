{
  domain = "proxmox-lab";
  node = "pve-lab";
  fqdn = "pve-lab.home.arpa";
  interface = "enp7s0";
  bridge = "br-lab";
  address = "10.0.1.240";
  gateway = "10.0.1.1";
  prefix = 24;
  mac = "52:54:00:4c:41:01";
  memoryMiB = 32768;
  cores = 8;
  systemDiskGiB = 64;
  storageDiskGiB = 256;
  diskDirectory = "/var/lib/proxmox-lab";
  iso = {
    url = "https://enterprise.proxmox.com/iso/proxmox-ve_9.2-1.iso";
    sha256 = "4e88fe416df9b527624a175f24c9aa07c714d3332afb1ee3dbf3879573ef2c6c";
  };
  sshPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDpqILWYPLnnke+4O3dAj61p8p+RghxZhTuP32TP6l07 david@nixos";
  forgejo = {
    address = "10.0.1.241";
    hostname = "forgejo-lab";
    mac = "52:54:00:4c:41:02";
    vmid = 310;
    restoreVmid = 311;
    memoryMiB = 4096;
    cores = 2;
    systemDiskGiB = 32;
    dataDiskGiB = 64;
  };
}
