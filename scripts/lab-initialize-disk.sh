#!/usr/bin/env bash
set -euo pipefail

# Called only for a designated virtual disk, never a discovered physical disk.
device=${1:?Expected device path}
label=${2:?Expected filesystem label}
[[ -b $device ]] || {
    echo "Missing data disk: $device" >&2
    exit 1
}
signature=$(blkid -p -o value -s TYPE "$device" || true)
existing_label=$(blkid -p -o value -s LABEL "$device" || true)
if [[ $signature == ext4 && $existing_label == "$label" ]]; then
    exit 0
fi
if [[ -n $signature || -n $existing_label || -n $(wipefs --no-act --noheadings "$device") ]]; then
    echo "Refusing to format $device: unexpected existing disk contents" >&2
    exit 1
fi
# Absence of a filesystem signature alone is not proof that a disk is empty.
if ! cmp --silent --bytes="$(blockdev --getsize64 "$device")" "$device" /dev/zero; then
    echo "Refusing to format $device: disk is not entirely zero-filled" >&2
    exit 1
fi
mkfs.ext4 -q -m 0 -L "$label" "$device"
