#!/usr/bin/env bash

# == update local nixos configuration with flake ==
sudo nixos-rebuild switch --flake .#wodan

# == update the flake lock file ==
sudo nix flake update

# == nix-shell -p alternative ==
# replace package with the actual name
nix shell nixpkgs#package

# == garbage collect old generations ==
nix-store --gc --print-roots | grep -vE "^(/nix/var|/run/\w+-system|\{memory|/proc)"
