#!/usr/bin/env bash

# == build the new configuration - /etc/nixos/configuration.nix ==
sudo nixos-rebuild switch

# == update local nixos configuration ==
time sudo nixos-rebuild switch -I nixos-config=configuration.nix

# == test the configuration change, until reboot ==
nixos-rebuild test

# == repl ==
nixos-rebuild repl

# == build a vm ==
nixos-rebuild build-vm
./result/bin/run-*-vm
