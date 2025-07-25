#!/usr/bin/env bash

# == update local nixos configuration ==
sudo nixos-rebuild switch -I nixos-config=configuration.nix

# == update local nixos configuration with flake ==
sudo nixos-rebuild switch --flake .#wodan

# == update the flake lock file ==
sudo nix flake update

# == build the new configuration - /etc/nixos/configuration.nix ==
sudo nixos-rebuild switch

# == update the nixos channel ==
# This is useful if you want to update the channel before rebuilding.
nix-channel --update

# == test the configuration change, until reboot ==
sudo nixos-rebuild test

# == boot into the new configuration on next reboot (great for big changes) ==
sudo nixos-rebuild boot

# == repl ==
sudo nixos-rebuild repl

# == build a vm ==
nixos-rebuild build-vm
./result/bin/run-*-vm

# == garbage collect old generations ==
nix-store --gc --print-roots | egrep -v "^(/nix/var|/run/\w+-system|\{memory|/proc)"
