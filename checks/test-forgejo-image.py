"""Boot the actual Forgejo image and verify persistence and rejected data disks."""

import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import time

IMAGE = Path(sys.argv[1]).resolve()
CONTROLLER = Path(sys.argv[2]).resolve()
spec = importlib.util.spec_from_file_location("lab", CONTROLLER)
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


def execute(args, **kwargs):
    return subprocess.run([str(a) for a in args], check=True, **kwargs)


def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def await_result(description, predicate, seconds=120):
    end = time.monotonic() + seconds
    while time.monotonic() < end:
        if predicate():
            return
        time.sleep(1)
    raise RuntimeError(description)


class Guest:
    def __init__(self, directory, data, label):
        self.directory = directory
        self.data = data
        self.label = label
        self.process = None
        self.serial = directory / f"{label}.log"
        self.root = directory / f"{label}-root.qcow2"

    def start(self):
        execute(
            [
                "qemu-img",
                "create",
                "-q",
                "-f",
                "qcow2",
                "-F",
                "qcow2",
                "-b",
                IMAGE,
                self.root,
            ]
        )
        args = [
            "qemu-system-x86_64",
            "-enable-kvm",
            "-cpu",
            "host",
            "-smp",
            "2",
            "-m",
            "4096",
            "-display",
            "none",
            "-serial",
            f"file:{self.serial}",
            "-drive",
            f"file={self.root},format=qcow2,if=none,id=root",
            "-device",
            "virtio-blk-pci,drive=root,serial=forgejo-root",
            "-netdev",
            "user,id=net0,net=10.0.1.0/24,host=10.0.1.1,"
            "hostfwd=tcp:127.0.0.1:22310-10.0.1.241:22,"
            "hostfwd=tcp:127.0.0.1:3000-10.0.1.241:3000,"
            "hostfwd=tcp:127.0.0.1:2222-10.0.1.241:2222",
            "-device",
            "virtio-net-pci,netdev=net0,mac=52:54:00:4c:41:02",
        ]
        if self.data:
            args += [
                "-drive",
                f"file={self.data},format=raw,if=none,id=data",
                "-device",
                "virtio-blk-pci,drive=data,serial=forgejo-state",
            ]
        self.process = subprocess.Popen(
            args, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE
        )
        await_result(
            "Guest SSH did not become available.",
            lambda: self.command("true").returncode == 0,
        )
        return self

    def command(self, command):
        return subprocess.run(
            [
                "ssh",
                "-p",
                "22310",
                "-o",
                "BatchMode=yes",
                "-o",
                "ConnectTimeout=2",
                "-o",
                "StrictHostKeyChecking=no",
                "-o",
                "UserKnownHostsFile=/dev/null",
                "david@127.0.0.1",
                command,
            ],
            capture_output=True,
            text=True,
        )

    def stop(self):
        if self.process and self.process.poll() is None:
            self.command("sudo poweroff")
            try:
                self.process.wait(timeout=30)
            except subprocess.TimeoutExpired:
                # Only this test's disposable QEMU process and disks are affected.
                self.process.terminate()
                self.process.wait(timeout=10)
        if self.process and self.process.stderr:
            self.process.stderr.close()

    def check_services(self):
        await_result(
            "Forgejo did not start.",
            lambda: (
                self.command(
                    "sudo systemctl is-active --quiet forgejo-admin"
                ).returncode
                == 0
            ),
        )

    def reject_data(self):
        await_result(
            "Expected disk initialization failure was not observed.",
            lambda: (
                self.command("systemctl is-failed --quiet forgejo-data-init").returncode
                == 0
            ),
        )
        assert self.command("systemctl is-active --quiet forgejo").returncode != 0
        assert self.command("systemctl is-active --quiet postgresql").returncode != 0
        assert (
            self.command("test -e /srv/forgejo/postgresql/16/PG_VERSION").returncode
            != 0
        )

    def __enter__(self):
        return self.start()

    def __exit__(self, error_type, error, traceback):
        if error:
            print(self.serial.read_text(errors="replace")[-10000:], file=sys.stderr)
            print(
                self.command(
                    "sudo journalctl -b -u forgejo -u postgresql -u forgejo-admin "
                    "-u forgejo-data-init --no-pager -n 60"
                ).stdout,
                file=sys.stderr,
            )
        self.stop()


def configure_test_controller(directory):
    original_ssh = lab.ssh_args

    def ssh(address, user):
        args = original_ssh(address, user)
        if user == "david":
            args[1:1] = ["-p", "22310"]
        return args

    lab.ssh_args = ssh
    lab.GUEST = "127.0.0.1"
    lab.STATE = directory / "controller"
    lab.STATE.mkdir()


with tempfile.TemporaryDirectory(prefix="nixcfg-forgejo-check-") as temporary:
    directory = Path(temporary)
    configure_test_controller(directory)
    for case in ("missing", "foreign", "dirty"):
        data = None
        before = None
        if case != "missing":
            data = directory / f"{case}.raw"
            with data.open("wb") as stream:
                stream.truncate(128 * 1024 * 1024)
            if case == "foreign":
                execute(["mkfs.ext4", "-q", "-L", "foreign-data", data])
            else:
                with data.open("r+b") as stream:
                    stream.seek(4096)
                    stream.write(b"Existing data must never be formatted.")
            before = sha(data)
        with Guest(directory, data, case) as guest:
            guest.reject_data()
        if data:
            assert sha(data) == before, f"The {case} disk was modified."
        print(
            f"PASS: {case} data disk is rejected without application data writes.",
            flush=True,
        )

    data = directory / "persistent.raw"
    with data.open("wb") as stream:
        stream.truncate(64 * 1024 * 1024 * 1024)
    with Guest(directory, data, "fresh") as guest:
        guest.check_services()
        commit = lab.smoke()
        identity = guest.command(
            "sudo sha256sum /srv/forgejo/admin-password "
            "/srv/forgejo/forgejo/custom/conf/secret_key"
        ).stdout
    print(
        "PASS: clean image boots, creates the administrator and supports Git.",
        flush=True,
    )

    # A fresh system disk must adopt the existing application disk.
    (lab.STATE / "known_hosts").unlink(missing_ok=True)
    with Guest(directory, data, "replace-system") as guest:
        guest.check_services()
        assert lab.smoke() == commit
        assert (
            guest.command(
                "sudo sha256sum /srv/forgejo/admin-password "
                "/srv/forgejo/forgejo/custom/conf/secret_key"
            ).stdout
            == identity
        )
        guest.command("sudo reboot")
        time.sleep(3)
        await_result(
            "The rebooted guest did not return.",
            lambda: guest.command("true").returncode == 0,
        )
        guest.check_services()
        assert lab.smoke() == commit
    print(
        "PASS: replacing the system disk and rebooting retain Git data and secrets.",
        flush=True,
    )

    copy = directory / "restored.raw"
    execute(["cp", "--sparse=always", data, copy])
    (lab.STATE / "known_hosts").unlink(missing_ok=True)
    with Guest(directory, copy, "restore-copy") as guest:
        guest.check_services()
        assert lab.smoke() == commit
    print(
        "PASS: an offline copy of the data disk restores on a fresh system image.",
        flush=True,
    )

print(
    json.dumps(
        {
            "result": "passed",
            "commit": commit,
            "cases": [
                "missing",
                "foreign",
                "dirty",
                "fresh",
                "replace-system",
                "reboot",
                "restore-copy",
            ],
        }
    )
)
