#!/usr/bin/env bash

# for all channels, check out https://channels.nixos.org/


# == list channels ==
sudo nix-channel --list

# == add a channel ==
nix-channel --add https://channels.nixos.org/nixos-25.05 nixos

# == upgrade NixOS ==
nixos-rebuild switch --upgrade


