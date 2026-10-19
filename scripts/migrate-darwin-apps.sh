#!/usr/bin/env bash
set -euo pipefail

primary_user=$1
version=$2
installer_package=$3

# Verify the replacement before removing the Homebrew-managed applications.
pkgutil --check-signature "$installer_package"
if brew_command=$(command -v brew); then
    installed_casks=$(sudo -H -u "$primary_user" "$brew_command" list --cask)
    for cask in alt-tab karabiner-elements; do
        if printf '%s\n' "$installed_casks" | grep -Fxq "$cask"; then
            sudo -H -u "$primary_user" "$brew_command" uninstall --cask "$cask"
        fi
    done
fi

installed_version=$(pkgutil --pkg-info org.pqrs.Karabiner-Elements 2>/dev/null | sed -n 's/^version: //p' || true)
if [[ "$installed_version" != "$version" ]]; then
    installer -pkg "$installer_package" -target /
fi
