#!/usr/bin/env bash

# == update local nixos configuration ==
time sudo nixos-rebuild switch -I nixos-config=configuration.nix

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
