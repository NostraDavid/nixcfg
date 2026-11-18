# Inspect the selected NixOS configuration from the flake.
[group('nixos')]
nixos-show host=default_host:
  @nix flake show .#nixosConfigurations."{{host}}"

# Update, switch, push to Cachix and collect garbage.
[group('nixos')]
[script("bash", "-euo", "pipefail")]
upgrade:
    sudo -v
    # read times out every 30s and gets EOF when the upgrade shell closes its pipe.
    coproc {
        while read -r -t 30 || (( $? > 128 )); do
            sudo -n -v || break
        done
    }
    time (
        set -x
        just update
        just pkgs
        just switch --non-interactive
        just cachix-push-all
        just gc-old --non-interactive
    )

# Test a host configuration temporarily; reverts after reboot.
[group('nixos')]
test host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild test "${opts[@]}" --flake path:.#"{{host}}"

# Apply a host configuration immediately and persist across reboots.
[group('nixos')]
[arg('noninteractive', long='non-interactive', value='-n')]
switch host=default_host noninteractive="":
  @sudo {{noninteractive}} -v; \
  time { \
  just forgejo-support-warning; \
  opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo {{noninteractive}} nixos-rebuild switch "${opts[@]}" --flake path:.#"{{host}}" 2>&1 | tee /tmp/just-switch.log; \
  if [ "{{host}}" = "wodan" ] && [ "$(hostname | cut -d . -f 1)" = "wodan" ]; then python3 scripts/snapshot-herdr-core.py; fi; \
  }

# Stage a host configuration for the next boot only.
[group('nixos')]
boot host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild boot "${opts[@]}" --flake path:.#"{{host}}"

# Build a VM for the selected host configuration.
[group('nixos')]
build-vm host=default_host:
  @nixos-rebuild build-vm --flake path:.#"{{host}}"

# Safer deploy when disk pressure is high.
[group('nixos')]
switch-clean host=default_host days="14":
  @just forgejo-support-warning
  @just gc-old "{{days}}"
  @just optimise-store
  @sudo nixos-rebuild test --flake .#"{{host}}"
  @sudo nixos-rebuild switch --flake .#"{{host}}"
