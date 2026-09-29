#!/bin/bash
set -euo pipefail
umask 077

# The controller prepends LAB_NODE and the disk initialization function.
[[ $(hostname -s) == "$LAB_NODE" ]] || {
    echo "Unexpected Proxmox node" >&2
    exit 1
}
[[ -f /root/nixcfg-lab-ready ]] && exit 0

initialize_disk /dev/disk/by-id/virtio-lab-storage lab-storage
mkdir -p /mnt/lab-storage
if ! grep -q '^LABEL=lab-storage ' /etc/fstab; then
    echo 'LABEL=lab-storage /mnt/lab-storage ext4 defaults 0 2' >>/etc/fstab
fi
mountpoint -q /mnt/lab-storage || mount /mnt/lab-storage
if ! grep -q '^dir: lab-store$' /etc/pve/storage.cfg; then
    pvesm add dir lab-store --path /mnt/lab-storage --content images,iso,backup,import,snippets --is_mountpoint 1
fi
mkdir -p /mnt/lab-storage/backups
mkdir -p /etc/network/interfaces.d
cat >/etc/network/interfaces.d/nixcfg-lab-restore <<'NETWORK'
auto vmbr1
iface vmbr1 inet manual
    bridge-ports none
    bridge-stp off
    bridge-fd 0
NETWORK
ip link show vmbr1 >/dev/null 2>&1 || ip link add vmbr1 type bridge
ip link set vmbr1 up

for source in /etc/apt/sources.list.d/pve-enterprise.sources /etc/apt/sources.list.d/ceph.sources; do
    if [[ -f $source ]] && grep -q enterprise.proxmox.com "$source"; then
        mv "$source" "$source.disabled"
    fi
done
cat >/etc/apt/sources.list.d/pve-lab.sources <<'SOURCES'
Types: deb
URIs: http://download.proxmox.com/debian/pve
Suites: trixie
Components: pve-no-subscription
Signed-By: /usr/share/keyrings/proxmox-archive-keyring.gpg
SOURCES
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get -y dist-upgrade
DEBIAN_FRONTEND=noninteractive apt-get -y --no-install-recommends install qemu-guest-agent
systemctl enable --now qemu-guest-agent
pveum user list --output-format json | python3 -c 'import json,sys; sys.exit(not any(u["userid"] == "nixlab@pve" for u in json.load(sys.stdin)))' ||
    pveum user add nixlab@pve --comment 'Local nixcfg lab automation'
pveum acl modify / --users nixlab@pve --roles PVEAdmin
if [[ ! -s /root/nixlab-token.json ]]; then
    pveum user token remove nixlab@pve lab >/dev/null 2>&1 || true
    pveum user token add nixlab@pve lab --privsep 0 --output-format json >/root/nixlab-token.json.tmp
    mv /root/nixlab-token.json.tmp /root/nixlab-token.json
fi
dpkg-query -W >/root/nixcfg-lab-package-versions.txt
touch /root/nixcfg-lab-ready
