"""Read-only boundary and recovery tests for the packaged lab controller."""

import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "lab", Path(__file__).parents[1] / "cmd/proxmox-lab.py"
)
lab = importlib.util.module_from_spec(spec)
spec.loader.exec_module(lab)


class LabBoundaries(unittest.TestCase):
    def test_production_and_duplicate_addresses_are_rejected(self):
        for address in ("192.168.2.100", lab.GUEST):
            with patch.object(lab, "PVE", address):
                with self.assertRaises(RuntimeError):
                    lab.validate_target()

    def test_foreign_arp_reply_aborts(self):
        result = subprocess.CompletedProcess([], 0, "", "")
        with (
            patch.object(lab, "run", return_value=result),
            patch.object(
                lab,
                "output",
                return_value=json.dumps([{"lladdr": "00:11:22:33:44:55"}]),
            ),
        ):
            with self.assertRaisesRegex(RuntimeError, "Address conflict"):
                lab.check_addresses("br-lab")

    def test_remote_mutations_require_the_lab_hostname(self):
        with patch.object(lab, "run") as execute:
            lab.remote("qm", "shutdown", "310")
        self.assertIn(
            'test "$(hostname -s)" = pve-lab &&', execute.call_args.args[0][-1]
        )

    def test_a_stuck_shutdown_never_forces_power_off(self):
        with (
            patch.object(lab, "domain_state", return_value="running"),
            patch.object(lab, "virsh") as virsh,
            patch.object(lab, "wait_for", side_effect=RuntimeError("Timed out")),
        ):
            with self.assertRaisesRegex(RuntimeError, "Timed out"):
                lab.down()
        self.assertEqual(
            virsh.call_args_list[0].args, ("shutdown", lab.DOMAIN, "--mode", "acpi")
        )
        self.assertEqual(virsh.call_count, 1)

    def test_invalid_backup_is_rejected_before_remote_access(self):
        with tempfile.TemporaryDirectory() as directory:
            backup = Path(directory) / "test.vma.zst"
            backup.write_bytes(b"broken backup")
            backup.with_suffix(".sha256").write_text("0" * 64)
            with patch.object(lab, "remote") as remote:
                with self.assertRaisesRegex(RuntimeError, "checksum"):
                    lab.restore(backup)
            remote.assert_not_called()

    def test_existing_restore_vm_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            backup = Path(directory) / "test.vma.zst"
            backup.write_bytes(b"test fixture")
            with patch.object(
                lab, "remote", return_value=subprocess.CompletedProcess([], 0, "", "")
            ) as remote:
                with self.assertRaisesRegex(RuntimeError, "already exists"):
                    lab.restore(backup)
            self.assertEqual(remote.call_count, 1)
            self.assertEqual(remote.call_args.args[:2], ("qm", "config"))

    def test_domain_redefinition_preserves_its_uuid(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            existing = subprocess.CompletedProcess(
                [], 0, "00000000-0000-0000-0000-000000000123", ""
            )
            with (
                patch.object(lab, "STATE", state),
                patch.object(lab, "virsh", return_value=existing),
            ):
                lab.define_domain()
            definition = lab.ET.fromstring((state / "domain.xml").read_text())
            self.assertEqual(definition.findtext("uuid"), existing.stdout)

    def test_reset_resumes_after_disks_have_already_been_archived(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            state = root / "state"
            state.mkdir()
            (state / "reset.json").write_text('{"tag":"123"}')
            (state / "api-token").write_text("test-only")
            disks = root / "disks"
            archived = disks / "archive" / "123"
            archived.mkdir(parents=True)
            (archived / "system.qcow2").write_text("old disk")
            config = {**lab.CONFIG, "diskDirectory": str(disks)}
            with (
                patch.object(lab, "STATE", state),
                patch.object(lab, "DISKS", disks / "current"),
                patch.object(lab, "CONFIG", config),
                patch.object(lab, "down"),
                patch.object(lab, "run"),
                patch.object(lab, "domain_state", return_value="absent"),
            ):
                lab.finish_reset()
            self.assertEqual((archived / "system.qcow2").read_text(), "old disk")
            self.assertTrue((disks / "current").is_dir())
            self.assertEqual(
                (root / "proxmox-lab-archive-123" / "api-token").read_text(),
                "test-only",
            )
            self.assertFalse((state / "reset.json").exists())

    def test_unreachable_hypervisor_is_not_treated_as_a_stopped_vm(self):
        failure = subprocess.CompletedProcess([], 1, "", "hypervisor unreachable")
        with patch.object(lab.subprocess, "run", return_value=failure):
            with self.assertRaisesRegex(RuntimeError, "hypervisor unreachable"):
                lab.domain_state()

    def test_failed_installer_start_can_be_retried(self):
        with tempfile.TemporaryDirectory() as directory:
            state = Path(directory)
            with (
                patch.object(lab, "STATE", state),
                patch.object(lab, "prepare"),
                patch.object(lab, "define_domain"),
                patch.object(lab, "domain_state", side_effect=["absent", "shut off"]),
                patch.object(lab, "virsh", side_effect=RuntimeError("start failed")),
            ):
                with self.assertRaisesRegex(RuntimeError, "start failed"):
                    lab.bootstrap_pve()
            self.assertFalse((state / "installer-started").exists())
            self.assertFalse((state / "installed").exists())

    def test_secret_files_have_private_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            secret = Path(directory) / "credential"
            lab.private_file(secret, "test-only")
            self.assertEqual(secret.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
