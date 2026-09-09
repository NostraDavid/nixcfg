default_host := `hostname --short`
default_cachix_cache := "thaumatorium"
nix_clean_env := "env -u LD_LIBRARY_PATH -u NIX_LD_LIBRARY_PATH -u LD_PRELOAD"
flake_update_delay_seconds := "5"
audient_mic_source := "alsa_input.usb-Audient_Audient_iD4-00.HiFi__Mic__source"

set shell := ["bash", "-euo", "pipefail", "-c"]

# Show available recipes and their parameters.
default:
  @just --list

import 'just/format.just'
import 'just/lint.just'
import 'just/nixos.just'
import 'just/packages.just'
import 'just/cachix.just'
import 'just/audio.just'
import 'just/proxmox.just'
import 'just/maintenance.just'
import 'just/security.just'
