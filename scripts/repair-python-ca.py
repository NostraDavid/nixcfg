#!/usr/bin/env python3
"""Remove distrusted roots from existing Python bundles without running pip."""

import argparse
import base64
import contextlib
import csv
import hashlib
import io
import os
import re
import shutil
import ssl
import stat
import sys
import tempfile
import zipfile
from pathlib import Path

# SHA-256 of the four root certificates, not their display names or PEM text.
DISTRUSTED = frozenset(
    [
        "d7a7a0fb5d7e2731d771e9484ebcdef71d5f0c3e0a2948782bc83ee0ea699ef4",
        "86a1ecba089c4a8d3bbe2734c612ba341d813e043cf9e8a862cd5c57a36bbe6b",
        "125609aa301da0a249b97a8239cb6a34216f44dcac9f3954b14292f2e8c8608f",
        "bc4d809b15189d78db3e1d8cf4f9726a795da1643ca5f1358e1ddb0edc0d7eb3",
    ]
)
CERTIFICATE = re.compile(
    rb"-----BEGIN CERTIFICATE-----.*?-----END CERTIFICATE-----", re.DOTALL
)


def filter_bundle(data: bytes) -> bytes:
    """Retain every other certificate, including custom private roots."""
    blocks = list(CERTIFICATE.finditer(data))
    if not blocks:
        raise ValueError("No standard PEM certificates found")
    if b"BEGIN TRUSTED CERTIFICATE" in data:
        raise ValueError(
            "OpenSSL trusted-certificate bundles require their owning Nix package"
        )

    def keep(match: re.Match[bytes]) -> bytes:
        der = ssl.PEM_cert_to_DER_cert(match[0].decode("ascii"))
        return b"" if hashlib.sha256(der).hexdigest() in DISTRUSTED else match[0]

    result = CERTIFICATE.sub(keep, data)
    if not CERTIFICATE.search(result):
        raise ValueError("Refusing to leave an empty trust store")
    return result


def update_record(data: bytes, name: str, content: bytes) -> bytes:
    rows = list(csv.reader(io.StringIO(data.decode("utf-8"))))
    digest = (
        base64.urlsafe_b64encode(hashlib.sha256(content).digest())
        .rstrip(b"=")
        .decode("ascii")
    )
    for row in rows:
        if row[0] == name:
            if row[1:] == ["sha256=" + digest, str(len(content))]:
                return data
            row[1:] = ["sha256=" + digest, str(len(content))]
            break
    else:
        raise ValueError(f"Missing RECORD entry: {name}")
    output = io.StringIO(newline="")
    csv.writer(output, lineterminator="\n").writerows(rows)
    return output.getvalue().encode("utf-8")


def atomic_write(path: Path, data: bytes) -> None:
    if path.is_symlink() or path.resolve().is_relative_to("/nix/store"):
        raise ValueError(f"Refusing to modify a symlink or Nix store file: {path}")
    metadata = path.stat()
    backup = path.with_name(path.name + ".before-emudhra")
    descriptor, name = tempfile.mkstemp(prefix=".ca-backup-", dir=path.parent)
    os.close(descriptor)
    staged_backup = Path(name)
    try:
        shutil.copy2(path, staged_backup)
        with staged_backup.open("rb") as source:
            os.fsync(source.fileno())
        with contextlib.suppress(FileExistsError):
            os.link(staged_backup, backup)
    finally:
        staged_backup.unlink(missing_ok=True)
    descriptor, name = tempfile.mkstemp(prefix=".ca-repair-", dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, "wb") as output:
            output.write(data)
            output.flush()
            os.fsync(output.fileno())
            os.fchmod(output.fileno(), stat.S_IMODE(metadata.st_mode))
            if os.geteuid() == 0:
                os.fchown(output.fileno(), metadata.st_uid, metadata.st_gid)
        temporary.replace(path)
    finally:
        temporary.unlink(missing_ok=True)


def repair_file(path: Path, apply: bool) -> bool:
    original = path.read_bytes()
    filtered = filter_bundle(original)
    updates = {path: filtered} if filtered != original else {}
    site = next(
        (
            parent
            for parent in path.parents
            if parent.name in {"site-packages", "dist-packages"}
        ),
        None,
    )
    if site is not None:
        package = path.relative_to(site).parts[0]
        for record in site.glob(f"{package}-*.dist-info/RECORD"):
            old = record.read_bytes()
            new = update_record(old, path.relative_to(site).as_posix(), filtered)
            if new != old:
                updates[record] = new
    if apply:
        for target, data in updates.items():
            atomic_write(target, data)
    return bool(updates)


def repair_wheel(path: Path, apply: bool) -> bool:
    with zipfile.ZipFile(path) as archive:
        infos = archive.infolist()
        if sum(info.file_size for info in infos) > 64 * 1024 * 1024:
            raise ValueError(f"Oversized bundled pip wheel: {path}")
        contents = {info.filename: archive.read(info) for info in infos}
    name = "pip/_vendor/certifi/cacert.pem"
    original = contents[name]
    contents[name] = filter_bundle(original)
    if contents[name] == original:
        return False
    record = next(name for name in contents if name.endswith(".dist-info/RECORD"))
    contents[record] = update_record(contents[record], name, contents[name])
    if apply:
        output = io.BytesIO()
        with zipfile.ZipFile(output, "w") as archive:
            for info in infos:
                archive.writestr(info, contents[info.filename])
        atomic_write(path, output.getvalue())
    return True


def discover(roots: list[Path]) -> list[Path]:
    def fail(error: OSError) -> None:
        raise error

    paths = set()
    for root in roots:
        if root.is_file():
            paths.add(root)
            continue
        if not root.is_dir():
            raise ValueError(f"Missing directory: {root}")
        for directory, dirs, files in os.walk(root, followlinks=False, onerror=fail):
            dirs[:] = [
                name
                for name in dirs
                if name not in {".git", "node_modules", "__pycache__"}
            ]
            parent = Path(directory)
            if parent.name == "certifi" and "cacert.pem" in files:
                paths.add(parent / "cacert.pem")
            paths.update(
                parent / name
                for name in files
                if name.startswith("pip-") and name.endswith(".whl")
            )
    return sorted(paths)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Repair files atomically; keep the first .before-emudhra backup. Default: read-only audit.",
    )
    parser.add_argument(
        "paths",
        nargs="+",
        type=Path,
        help="Trusted environment directories or explicit CA files to inspect; directory symlinks are not followed.",
    )
    args = parser.parse_args()
    changed = failed = 0
    for path in discover(args.paths):
        try:
            repair = repair_wheel if path.suffix == ".whl" else repair_file
            if repair(path, args.apply):
                changed += 1
                print(f"{'Repaired' if args.apply else 'Would repair'}: {path}")
        except (OSError, ValueError, KeyError, zipfile.BadZipFile) as error:
            failed += 1
            print(f"Cannot inspect or repair {path}: {error}", file=sys.stderr)
    print(f"{'Repaired' if args.apply else 'Pending'}: {changed}; failures: {failed}")
    return int(failed > 0 or (changed > 0 and not args.apply))


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
