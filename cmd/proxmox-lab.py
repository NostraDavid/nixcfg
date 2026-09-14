"""Nix-packaged controller for the local lab. Run through just or nix run."""

import argparse
import fcntl
import grp
import hashlib
import http.cookiejar
import ipaddress
import json
import os
from pathlib import Path
import secrets
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

CONFIG = json.loads(Path(os.environ["PROXMOX_LAB_CONFIG"]).read_text())
REPO = Path.cwd()
STATE = (
    Path(os.environ.get("XDG_STATE_HOME", str(Path.home() / ".local/state")))
    / "proxmox-lab"
)
DISKS = Path(CONFIG["diskDirectory"]) / "current"
DOMAIN = CONFIG["domain"]
PVE = CONFIG["address"]
GUEST = CONFIG["forgejo"]["address"]
VMID = str(CONFIG["forgejo"]["vmid"])


def run(args, *, capture=False, check=True, input=None, timeout=None, env=None):
    result = subprocess.run(
        [str(arg) for arg in args],
        input=input,
        text=True,
        check=False,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        timeout=timeout,
        env=env,
    )
    if check and result.returncode:
        detail = result.stderr.strip() if capture else ""
        raise RuntimeError(f"{args[0]} failed ({result.returncode}). {detail}")
    return result


def output(args, **kwargs):
    return run(args, capture=True, **kwargs).stdout.strip()


def wait_for(description, predicate, seconds):
    deadline = time.monotonic() + seconds
    print(description, flush=True)
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(3)
    raise RuntimeError(f"Timed out: {description}. Use lab-status to inspect logs.")


def virsh(*args, **kwargs):
    return run(["virsh", "--connect", "qemu:///system", *args], **kwargs)


def domain_state():
    listed = virsh("list", "--all", "--name", capture=True)
    if DOMAIN not in listed.stdout.splitlines():
        return "absent"
    return virsh("domstate", DOMAIN, capture=True).stdout.strip()


def ssh_args(address, user):
    return [
        "ssh",
        "-o",
        "BatchMode=yes",
        "-o",
        "ConnectTimeout=5",
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-o",
        f"UserKnownHostsFile={STATE / 'known_hosts'}",
        f"{user}@{address}",
    ]


def remote(*args, guest=False, **kwargs):
    address, user = (GUEST, "david") if guest else (PVE, "root")
    expected = CONFIG["forgejo"]["hostname"] if guest else CONFIG["node"]
    command = (
        'test "$(hostname -s)" = '
        + shlex.quote(expected)
        + " && "
        + shlex.join([str(arg) for arg in args])
    )
    return run([*ssh_args(address, user), command], **kwargs)


def private_file(path, text):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    temp = path.with_suffix(path.suffix + ".tmp")
    temp.write_text(text)
    temp.chmod(0o600)
    temp.replace(path)


def build_image():
    result = output(
        [
            "nix",
            "build",
            "path:.#forgejo-lab-image",
            "--out-link",
            STATE / "forgejo-image",
            "--print-out-paths",
        ]
    )
    images = list(Path(result.splitlines()[-1]).glob("*.qcow2"))
    if len(images) != 1:
        raise RuntimeError("Expected exactly one QCOW2 image from the Nix build.")
    return str(images[0])


def require_repo():
    if not (REPO / "infra/proxmox-lab/settings.nix").is_file():
        raise RuntimeError("Run this command from the nixcfg checkout.")


def validate_target():
    if CONFIG["node"] != "pve-lab" or DOMAIN != "proxmox-lab":
        raise RuntimeError("Unexpected lab identity.")
    subnet = ipaddress.ip_network(
        f"{CONFIG['gateway']}/{CONFIG['prefix']}", strict=False
    )
    addresses = [PVE, GUEST]
    if len(set(addresses)) != 2 or any(
        ipaddress.ip_address(a) not in subnet for a in addresses
    ):
        raise RuntimeError("Lab addresses must be distinct and on the configured LAN.")
    if "192.168.2.100" in addresses:
        raise RuntimeError("Production cannot be used as a lab target.")


def check_addresses(interface):
    for address, expected_mac in [
        (PVE, CONFIG["mac"]),
        (GUEST, CONFIG["forgejo"]["mac"]),
    ]:
        # The kernel also resolves ARP for ping, including when ICMP is filtered.
        run(["ping", "-c", "1", "-W", "1", address], capture=True, check=False)
        neighbors = json.loads(output(["ip", "-j", "neigh", "show", "to", address]))
        for neighbor in neighbors:
            mac = neighbor.get("lladdr")
            if mac and mac.lower() != expected_mac.lower():
                raise RuntimeError(f"Address conflict: {address} belongs to {mac}.")
        if os.geteuid() == 0 and not any(n.get("lladdr") for n in neighbors):
            result = run(
                ["arping", "-D", "-I", interface, "-c", "3", "-w", "4", address],
                capture=True,
                check=False,
            )
            if result.returncode:
                raise RuntimeError(
                    f"Address {address} is in use or ARP verification failed: {result.stderr}"
                )


def network():
    bridge, interface = CONFIG["bridge"], CONFIG["interface"]
    if Path(f"/sys/class/net/{bridge}/brif/{interface}").exists():
        check_addresses(bridge)
        print(f"{bridge} is active.")
        return
    original = json.loads(output(["ip", "-j", "address", "show", interface]))
    original_ip = next(
        a["local"] for a in original[0]["addr_info"] if a["family"] == "inet"
    )
    bus = [
        "busctl",
        "call",
        "org.freedesktop.NetworkManager",
        "/org/freedesktop/NetworkManager",
        "org.freedesktop.NetworkManager",
    ]
    checkpoint = shlex.split(
        output([*bus, "CheckpointCreate", "aouu", "0", "120", "0"])
    )[1]
    try:
        run(["nmcli", "--wait", "0", "connection", "up", "lab-bridge"])
        run(["nmcli", "--wait", "60", "connection", "up", "lab-uplink"])

        def bridge_has_address():
            current = json.loads(output(["ip", "-j", "address", "show", bridge]))
            return any(a["family"] == "inet" for a in current[0]["addr_info"])

        wait_for("Waiting for DHCP on the bridge.", bridge_has_address, 60)
        current = json.loads(output(["ip", "-j", "address", "show", bridge]))
        if original_ip not in [
            a["local"] for a in current[0]["addr_info"] if a["family"] == "inet"
        ]:
            raise RuntimeError("The bridge did not retain the desktop address.")
        run(["ping", "-c", "2", "-W", "2", CONFIG["gateway"]], capture=True)
        code = output(
            [
                "curl",
                "--silent",
                "--show-error",
                "--connect-timeout",
                "5",
                "--max-time",
                "10",
                "--output",
                "/dev/null",
                "--write-out",
                "%{http_code}",
                "https://192.168.2.100:8006/api2/json/version",
            ]
        )
        if code not in ("200", "401"):
            raise RuntimeError("The production route was not preserved.")
        check_addresses(bridge)
        run([*bus, "CheckpointDestroy", "o", checkpoint])
    except BaseException:
        run([*bus, "CheckpointRollback", "o", checkpoint], check=False)
        raise
    print(
        f"Bridge active; desktop address {original_ip} and production route retained."
    )


def domain_xml(install=False):
    root = ET.Element("domain", type="kvm")
    ET.SubElement(root, "name").text = DOMAIN
    ET.SubElement(root, "description").text = "nixcfg disposable local Proxmox lab"
    ET.SubElement(root, "memory", unit="MiB").text = str(CONFIG["memoryMiB"])
    ET.SubElement(root, "vcpu").text = str(CONFIG["cores"])
    os_xml = ET.SubElement(root, "os")
    ET.SubElement(os_xml, "type", arch="x86_64", machine="pc-q35-10.2").text = "hvm"
    ET.SubElement(os_xml, "boot", dev="cdrom" if install else "hd")
    features = ET.SubElement(root, "features")
    ET.SubElement(features, "acpi")
    ET.SubElement(features, "apic")
    cpu = ET.SubElement(root, "cpu", mode="host-passthrough")
    ET.SubElement(cpu, "feature", policy="require", name="svm")
    ET.SubElement(root, "on_poweroff").text = "destroy"
    ET.SubElement(root, "on_reboot").text = "destroy" if install else "restart"
    ET.SubElement(root, "on_crash").text = "preserve"
    devices = ET.SubElement(root, "devices")
    for name, target, serial in [
        ("system", "vda", "lab-root"),
        ("storage", "vdb", "lab-storage"),
    ]:
        disk = ET.SubElement(devices, "disk", type="file", device="disk")
        ET.SubElement(
            disk, "driver", name="qemu", type="qcow2", cache="none", discard="unmap"
        )
        ET.SubElement(disk, "source", file=str(DISKS / f"{name}.qcow2"))
        ET.SubElement(disk, "target", dev=target, bus="virtio")
        ET.SubElement(disk, "serial").text = serial
    if install:
        disk = ET.SubElement(devices, "disk", type="file", device="cdrom")
        ET.SubElement(disk, "driver", name="qemu", type="raw")
        ET.SubElement(disk, "source", file=str(DISKS / "installer.iso"))
        ET.SubElement(disk, "target", dev="sda", bus="sata")
        ET.SubElement(disk, "readonly")
    net = ET.SubElement(devices, "interface", type="bridge")
    ET.SubElement(net, "mac", address=CONFIG["mac"])
    ET.SubElement(net, "source", bridge=CONFIG["bridge"])
    ET.SubElement(net, "model", type="virtio")
    serial = ET.SubElement(devices, "serial", type="file")
    ET.SubElement(serial, "source", path=str(DISKS / "serial.log"), append="on")
    ET.SubElement(serial, "target", port="0")
    channel = ET.SubElement(devices, "channel", type="unix")
    ET.SubElement(channel, "target", type="virtio", name="org.qemu.guest_agent.0")
    ET.SubElement(
        devices, "graphics", type="vnc", port="-1", autoport="yes", listen="127.0.0.1"
    )
    return ET.tostring(root, encoding="unicode")


def define_domain(install=False):
    xml = STATE / "domain.xml"
    definition = ET.fromstring(domain_xml(install))
    existing = virsh("domuuid", DOMAIN, capture=True, check=False)
    if existing.returncode == 0:
        ET.SubElement(definition, "uuid").text = existing.stdout.strip()
    xml.write_text(ET.tostring(definition, encoding="unicode"))
    virsh("define", xml)
    virsh("autostart", "--disable", DOMAIN)


def prepare():
    if not DISKS.is_dir() or not os.access(DISKS, os.W_OK):
        raise RuntimeError(
            "Activate the wodan NixOS configuration first; lab disk storage is not writable."
        )
    stamp = STATE / "settings.json"
    if stamp.exists() and json.loads(stamp.read_text()) != CONFIG:
        raise RuntimeError(
            "Lab settings changed. Restore them or use lab-reset to archive this environment."
        )
    private_file(stamp, json.dumps(CONFIG, indent=2))
    cache = STATE / "cache"
    cache.mkdir(exist_ok=True)
    iso = cache / "proxmox.iso"
    if not iso.exists():
        run(
            [
                "curl",
                "--fail",
                "--silent",
                "--show-error",
                "--location",
                "--retry",
                "3",
                "--continue-at",
                "-",
                "--output",
                iso.with_suffix(".part"),
                CONFIG["iso"]["url"],
            ]
        )
        iso.with_suffix(".part").replace(iso)
    with iso.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    if digest != CONFIG["iso"]["sha256"]:
        raise RuntimeError("Proxmox ISO checksum mismatch; refusing installation.")
    if not (DISKS / "installer.iso").exists():
        password_path = STATE / "pve-password"
        if not password_path.exists():
            private_file(password_path, secrets.token_urlsafe(24) + "\n")
        password_hash = output(
            ["openssl", "passwd", "-6", "-stdin"], input=password_path.read_text()
        )
        answer = f"""
[global]
keyboard = "en-us"
country = "nl"
fqdn = "{CONFIG["fqdn"]}"
mailto = "root@pve-lab.home.arpa"
timezone = "Europe/Amsterdam"
root-password-hashed = "{password_hash}"
root-ssh-keys = [{json.dumps(CONFIG["sshPublicKey"])}]

[network]
source = "from-answer"
cidr = "{PVE}/{CONFIG["prefix"]}"
dns = "{CONFIG["gateway"]}"
gateway = "{CONFIG["gateway"]}"
filter.ID_NET_NAME_MAC = "enx{CONFIG["mac"].replace(":", "")}"

[disk-setup]
filesystem = "ext4"
disk-list = ["vda"]
lvm.swapsize = 0
lvm.maxvz = 0

[first-boot]
source = "from-iso"
ordering = "fully-up"
"""
        private_file(STATE / "answer.toml", answer)
        initialize = (REPO / "cmd/lab-initialize-disk.sh").read_text()
        initialize = "\n".join(initialize.splitlines()[2:]).replace(
            "exit 0", "return 0"
        )
        boot = (REPO / "cmd/proxmox-lab-first-boot.sh").read_text()
        boot = (
            f"#!/bin/bash\nLAB_NODE={shlex.quote(CONFIG['node'])}\n"
            f"initialize_disk() {{\n{initialize}\n}}\n"
            + "\n".join(boot.splitlines()[1:])
            + "\n"
        )
        private_file(STATE / "first-boot.sh", boot)
        (STATE / "first-boot.sh").chmod(0o700)
        run(
            ["proxmox-auto-install-assistant", "validate-answer", STATE / "answer.toml"]
        )
        run(
            [
                "proxmox-auto-install-assistant",
                "prepare-iso",
                iso,
                "--fetch-from",
                "iso",
                "--answer-file",
                STATE / "answer.toml",
                "--on-first-boot",
                STATE / "first-boot.sh",
                "--output",
                DISKS / "installer.iso.tmp",
            ]
        )
        (DISKS / "installer.iso.tmp").chmod(0o640)
        (DISKS / "installer.iso.tmp").replace(DISKS / "installer.iso")
    for name, size in [
        ("system", CONFIG["systemDiskGiB"]),
        ("storage", CONFIG["storageDiskGiB"]),
    ]:
        disk = DISKS / f"{name}.qcow2"
        if not disk.exists():
            run(["qemu-img", "create", "-f", "qcow2", disk, f"{size}G"])
            disk.chmod(0o660)


def bootstrap_pve():
    ready = STATE / "installed"
    started = STATE / "installer-started"
    if not ready.exists():
        prepare()
        if not started.exists():
            if domain_state() == "running":
                raise RuntimeError(
                    "An unrecorded domain is running; refusing to replace it."
                )
            define_domain(install=True)
            # Record before starting: a retry must never reinstall over a used disk.
            private_file(started, "installer requested\n")
            try:
                virsh("start", DOMAIN)
            except RuntimeError:
                if domain_state() == "shut off":
                    started.unlink()
                raise
        wait_for(
            "Installing Proxmox; waiting for the installer to shut down.",
            lambda: domain_state() == "shut off",
            1800,
        )
        private_file(ready, "installer finished; normal boot must still be verified\n")
    if domain_state() in ("absent", "shut off"):
        define_domain()
        virsh("start", DOMAIN)
    wait_for(
        "Waiting for Proxmox first-boot configuration.",
        lambda: (
            remote(
                "test", "-f", "/root/nixcfg-lab-ready", capture=True, check=False
            ).returncode
            == 0
        ),
        1800,
    )
    token = json.loads(remote("cat", "/root/nixlab-token.json", capture=True).stdout)
    private_file(STATE / "api-token", token["full-tokenid"] + "=" + token["value"])
    private_file(
        STATE / "pve-ca.pem",
        remote("cat", "/etc/pve/pve-root-ca.pem", capture=True).stdout,
    )
    private_file(
        STATE / "package-versions.txt",
        remote("cat", "/root/nixcfg-lab-package-versions.txt", capture=True).stdout,
    )


def api_ready():
    token = (STATE / "api-token").read_text().strip()
    request_config = (
        "header = " + json.dumps("Authorization: PVEAPIToken=" + token) + "\n"
    )
    response = run(
        [
            "curl",
            "--fail",
            "--silent",
            "--show-error",
            "--max-time",
            "5",
            "--cacert",
            STATE / "pve-ca.pem",
            "--config",
            "-",
            f"https://{PVE}:8006/api2/json/version",
        ],
        capture=True,
        check=False,
        input=request_config,
    )
    return response.returncode == 0


def tofu_environment():
    return {
        **os.environ,
        "SSL_CERT_FILE": str(STATE / "pve-ca.pem"),
        "TF_VAR_api_token": (STATE / "api-token").read_text(),
    }


def provision_guest():
    directory = STATE / "tofu"
    directory.mkdir(exist_ok=True)
    for source in (REPO / "infra/proxmox-lab").glob("*.tf"):
        shutil.copyfile(source, directory / source.name)
    lock = REPO / "infra/proxmox-lab/.terraform.lock.hcl"
    if lock.exists():
        shutil.copyfile(lock, directory / lock.name)
    variables = directory / "lab.auto.tfvars.json"
    if not variables.exists():
        cfg = CONFIG["forgejo"]
        values = {
            "endpoint": f"https://{PVE}:8006/",
            "node": CONFIG["node"],
            "image_path": build_image(),
            "address": GUEST,
            "vmid": cfg["vmid"],
            "mac": cfg["mac"],
            "cores": cfg["cores"],
            "memory_mb": cfg["memoryMiB"],
            "system_disk_gb": cfg["systemDiskGiB"],
            "data_disk_gb": cfg["dataDiskGiB"],
        }
        private_file(variables, json.dumps(values, indent=2))
    pinned_image = Path(json.loads(variables.read_text())["image_path"]).parent
    run(
        [
            "nix-store",
            "--add-root",
            STATE / "provision-image",
            "--indirect",
            "--realise",
            pinned_image,
        ],
        capture=True,
    )
    args = ["tofu", f"-chdir={directory}"]
    environment = tofu_environment()
    run([*args, "init", "-input=false"], env=environment)
    run([*args, "apply", "-input=false", "-auto-approve"], env=environment)
    wait_for(
        "Waiting for Forgejo and its administrator.",
        lambda: (
            remote(
                "sudo",
                "systemctl",
                "is-active",
                "--quiet",
                "forgejo-admin.service",
                guest=True,
                capture=True,
                check=False,
            ).returncode
            == 0
        ),
        900,
    )


def up():
    require_repo()
    if (STATE / "reset.json").exists():
        finish_reset()
    network()
    bootstrap_pve()
    wait_for("Waiting for the authenticated Proxmox API.", api_ready, 180)
    provision_guest()
    status()


def down():
    state = domain_state()
    if state in ("absent", "shut off"):
        print("Lab is stopped.")
        return
    if state != "running":
        raise RuntimeError(
            f"Unexpected domain state: {state}; refusing to force power off."
        )
    virsh("shutdown", DOMAIN, "--mode", "acpi")
    wait_for(
        "Waiting for guests and Proxmox to shut down gracefully.",
        lambda: domain_state() == "shut off",
        300,
    )


def status():
    print(f"Proxmox: {domain_state()}")
    print(f"Proxmox UI: https://{PVE}:8006/")
    print(f"Forgejo UI: http://{GUEST}:3000/")
    print(f"Credentials: {STATE / 'pve-password'}; Forgejo: just forgejo-password")
    if domain_state() == "running":
        remote("systemctl", "--failed", "--no-pager", capture=False, check=False)
        remote("qm", "list", check=False)
    print(f"Serial log: {DISKS / 'serial.log'}")
    print(f"Controller state: {STATE}")


def finish_reset():
    journal = STATE / "reset.json"
    transaction = json.loads(journal.read_text())
    tag = transaction["tag"]
    if not tag.isdigit():
        raise RuntimeError("Invalid reset journal.")
    down()
    if domain_state() != "absent":
        virsh("undefine", DOMAIN)
    archive = Path(CONFIG["diskDirectory"]) / "archive" / tag
    if not archive.exists():
        DISKS.rename(archive)
    DISKS.mkdir(mode=0o2770, exist_ok=True)
    DISKS.chmod(0o2770)
    run(["setfacl", "-m", "u:qemu-libvirtd:rwx", DISKS])
    archive_state = STATE.parent / f"proxmox-lab-archive-{tag}"
    archive_state.mkdir(mode=0o700, exist_ok=True)
    for child in list(STATE.iterdir()):
        if child.name not in ("controller.lock", "reset.json", "cache"):
            target = archive_state / child.name
            if target.exists():
                raise RuntimeError(
                    f"Reset archive already contains {child.name}; refusing overwrite."
                )
            child.rename(target)
    journal.unlink()
    print(f"Archived disks to {archive}; credentials and state to {archive_state}.")


def reset():
    require_repo()
    journal = STATE / "reset.json"
    if not journal.exists():
        private_file(journal, json.dumps({"tag": str(time.time_ns())}))
    finish_reset()
    up()


def backup():
    destination = STATE / "backups"
    destination.mkdir(exist_ok=True)
    remote(
        "vzdump",
        VMID,
        "--mode",
        "stop",
        "--compress",
        "zstd",
        "--dumpdir",
        "/mnt/lab-storage/backups",
    )
    name = remote(
        "bash",
        "-c",
        f"ls -1t /mnt/lab-storage/backups/vzdump-qemu-{VMID}-*.vma.zst | head -1",
        capture=True,
    ).stdout.strip()
    if not name.startswith(
        f"/mnt/lab-storage/backups/vzdump-qemu-{VMID}-"
    ) or not name.endswith(".vma.zst"):
        raise RuntimeError("The backup did not produce the expected VM archive.")
    local = destination / Path(name).name
    with local.with_suffix(".part").open("wb") as target:
        subprocess.run(
            [*ssh_args(PVE, "root"), shlex.join(["cat", name])],
            stdout=target,
            check=True,
        )
    local.with_suffix(".part").replace(local)
    local.chmod(0o600)
    with local.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    private_file(local.with_suffix(".sha256"), digest + "\n")
    print(f"Backup: {local}")
    return local


def guest_command(vmid, *args):
    if args and "/" not in args[0]:
        args = (f"/run/current-system/sw/bin/{args[0]}", *args[1:])
    result = json.loads(
        remote(
            "qm",
            "guest",
            "exec",
            str(vmid),
            "--timeout",
            "120",
            "--",
            *args,
            capture=True,
        ).stdout
    )
    if not result.get("exited") or result.get("exitcode") != 0:
        raise RuntimeError(
            "Restored guest command failed: "
            + result.get("err-data", result.get("out-data", "no output"))
        )
    return result.get("out-data", "")


def restore(archive):
    source = Path(archive).resolve()
    if not source.is_file() or not source.name.endswith(".vma.zst"):
        raise RuntimeError("Expected a local .vma.zst backup.")
    checksum = source.with_suffix(".sha256")
    if checksum.exists():
        with source.open("rb") as stream:
            digest = hashlib.file_digest(stream, "sha256").hexdigest()
        if digest != checksum.read_text().strip():
            raise RuntimeError("Backup checksum mismatch.")
    restore_id = str(CONFIG["forgejo"]["restoreVmid"])
    existing = remote("qm", "config", restore_id, capture=True, check=False)
    if existing.returncode == 0:
        raise RuntimeError(
            f"Restore VM {restore_id} already exists; it will not be overwritten."
        )
    remote_path = f"/mnt/lab-storage/backups/{source.name}"
    with source.open("rb") as stream:
        subprocess.run(
            [
                *ssh_args(PVE, "root"),
                shlex.join(["bash", "-c", f"cat > {shlex.quote(remote_path)}.upload"]),
            ],
            stdin=stream,
            check=True,
        )
    remote("mv", remote_path + ".upload", remote_path)
    remote(
        "qmrestore", remote_path, restore_id, "--storage", "lab-store", "--unique", "1"
    )
    remote("mkdir", "-p", "/etc/network/interfaces.d")
    remote(
        "tee",
        "/etc/network/interfaces.d/nixcfg-lab-restore",
        input="auto vmbr1\niface vmbr1 inet manual\n\tbridge-ports none\n\tbridge-stp off\n\tbridge-fd 0\n",
        capture=True,
    )
    # The restored static IP must never be connected to the live LAN.
    remote(
        "bash",
        "-c",
        "ip link show vmbr1 >/dev/null 2>&1 || ip link add vmbr1 type bridge; ip link set vmbr1 up",
    )
    remote(
        "qm",
        "set",
        restore_id,
        "--name",
        "forgejo-restore",
        "--onboot",
        "0",
        "--net0",
        "virtio,bridge=vmbr1",
    )
    remote("qm", "start", restore_id)
    wait_for(
        "Waiting for the isolated restored VM.",
        lambda: (
            remote(
                "qm", "agent", restore_id, "ping", capture=True, check=False
            ).returncode
            == 0
        ),
        300,
    )
    guest_command(restore_id, "systemctl", "start", "forgejo-admin")
    guest_command(
        restore_id, "curl", "--fail", "--silent", "http://127.0.0.1:3000/api/healthz"
    )
    print(f"Backup restored to isolated VM {restore_id}; the original VM is unchanged.")


def deploy():
    require_repo()
    remote("sudo", "true", guest=True, capture=True)
    run(
        [
            "nixos-rebuild",
            "switch",
            "--flake",
            "path:.#forgejo-lab",
            "--target-host",
            f"david@{GUEST}",
            "--sudo",
        ],
        env={**os.environ, "NIX_SSHOPTS": shlex.join(ssh_args(GUEST, "david")[1:-1])},
    )


def api(method, path, body=None):
    password = remote(
        "sudo", "cat", "/srv/forgejo/admin-password", guest=True, capture=True
    ).stdout.strip()
    args = [
        "curl",
        "--fail-with-body",
        "--silent",
        "--show-error",
        "--config",
        "-",
        "--request",
        method,
        "--header",
        "Content-Type: application/json",
        f"http://{GUEST}:3000/api/v1/{path}",
    ]
    if body is not None:
        args += ["--data", json.dumps(body)]
    # Credentials go through stdin, never the command line or logs.
    return run(args, input=f'user = "david:{password}"\n', capture=True, check=False)


def web_login():
    password = remote(
        "sudo", "cat", "/srv/forgejo/admin-password", guest=True, capture=True
    ).stdout.strip()
    base = f"http://{GUEST}:3000"
    opener = urllib.request.build_opener(
        urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar())
    )
    with opener.open(base + "/user/login", timeout=10) as response:
        response.read()
    request = urllib.request.Request(
        base + "/user/login",
        data=urllib.parse.urlencode(
            {"user_name": "david", "password": password}
        ).encode(),
        headers={"Origin": base, "Referer": base + "/user/login"},
    )
    with opener.open(request, timeout=10) as response:
        page = response.read().decode()
        if "/user/login" in response.url or "/user/logout" not in page:
            raise RuntimeError("Forgejo web-form authentication did not complete.")


def smoke():
    web_login()
    repositories = api("GET", "user/repos")
    if repositories.returncode:
        raise RuntimeError("Forgejo API authentication failed.")
    name = "nixcfg-lab-smoke"
    if not any(item["name"] == name for item in json.loads(repositories.stdout)):
        result = api(
            "POST",
            "user/repos",
            {"name": name, "private": True, "description": "nixcfg lab verification"},
        )
        if result.returncode:
            raise RuntimeError("Cannot create the lab verification repository.")
    keys = json.loads(api("GET", "user/keys").stdout)
    public_key = " ".join(CONFIG["sshPublicKey"].split()[:2])
    if not any(" ".join(key["key"].split()[:2]) == public_key for key in keys):
        if api(
            "POST", "user/keys", {"title": "nixcfg-lab", "key": CONFIG["sshPublicKey"]}
        ).returncode:
            raise RuntimeError("Cannot register the lab Git SSH key.")
    ssh = ssh_args(GUEST, "forgejo")[:-1]
    environment = {**os.environ, "GIT_SSH_COMMAND": shlex.join(ssh)}
    url = f"ssh://forgejo@{GUEST}:2222/david/{name}.git"
    with tempfile.TemporaryDirectory(prefix="forgejo-smoke-") as directory:
        clone = Path(directory) / "repository"
        run(["git", "clone", url, clone], env=environment)
        marker = clone / "verification.txt"
        if not marker.exists():
            marker.write_text("Forgejo lab persistence check.\n")
            run(["git", "-C", clone, "add", "verification.txt"])
            run(
                [
                    "git",
                    "-C",
                    clone,
                    "-c",
                    "user.name=Lab verification",
                    "-c",
                    "user.email=lab@localhost",
                    "commit",
                    "-m",
                    "lab: verify repository persistence",
                ]
            )
            run(["git", "-C", clone, "push", "origin", "HEAD"], env=environment)
        expected = output(["git", "-C", clone, "rev-parse", "HEAD"])
        second = Path(directory) / "readback"
        run(["git", "clone", url, second], env=environment)
        if (
            output(["git", "-C", second, "rev-parse", "HEAD"]) != expected
            or (second / "verification.txt").read_bytes() != marker.read_bytes()
        ):
            raise RuntimeError("Git push/clone readback failed.")
    print(f"Forgejo login and Git push/clone passed: {expected}")
    return expected


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "command",
        choices=[
            "up",
            "down",
            "status",
            "reset",
            "network",
            "image",
            "test-image",
            "test-controller",
            "deploy",
            "backup",
            "restore",
            "smoke",
            "password",
            "check",
            "plan",
        ],
    )
    parser.add_argument("archive", nargs="?")
    args = parser.parse_args()
    validate_target()
    if args.command == "network":
        network()
        return
    if args.command in ("check", "plan"):
        require_repo()
        print(json.dumps(CONFIG, indent=2) if args.command == "plan" else "ok")
        return
    if args.command == "test-controller":
        require_repo()
        run([sys.executable, REPO / "checks/test-proxmox-lab.py"])
        return
    STATE.mkdir(parents=True, exist_ok=True, mode=0o700)
    STATE.chmod(0o700)
    if args.command == "status":
        status()
        return
    with (STATE / "controller.lock").open("a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise RuntimeError("Another lab command is already running.") from error
        if args.command == "restore":
            if not args.archive:
                raise RuntimeError(
                    "Provide the backup file to restore into an isolated VM."
                )
            restore(args.archive)
        elif args.command == "password":
            remote("sudo", "cat", "/srv/forgejo/admin-password", guest=True)
        elif args.command == "image":
            print(build_image())
        elif args.command == "test-image":
            require_repo()
            run(
                [
                    sys.executable,
                    REPO / "checks/test-forgejo-image.py",
                    build_image(),
                    Path(__file__),
                ]
            )
        else:
            {
                "up": up,
                "down": down,
                "status": status,
                "reset": reset,
                "deploy": deploy,
                "backup": backup,
                "smoke": smoke,
            }[args.command]()


if __name__ == "__main__":
    try:
        group = grp.getgrnam("libvirtd")
        if group.gr_gid not in [*os.getgroups(), os.getegid()] and os.getuid() != 0:
            import getpass

            if getpass.getuser() in group.gr_mem:
                os.execvp(
                    "sg",
                    [
                        "sg",
                        "libvirtd",
                        "-c",
                        shlex.join([sys.executable, __file__, *sys.argv[1:]]),
                    ],
                )
    except KeyError:
        pass
    try:
        main()
    except (RuntimeError, subprocess.SubprocessError, OSError, ValueError) as error:
        print(f"proxmox-lab: {error}", file=sys.stderr)
        sys.exit(1)
