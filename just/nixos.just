# Inspect the selected NixOS configuration from the flake.
[group('nixos')]
nixos-show host=default_host:
  @nix flake show .#nixosConfigurations."{{host}}"

# Test a host configuration temporarily; reverts after reboot.
[group('nixos')]
test host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild test "${opts[@]}" --flake path:.#"{{host}}"

# Apply a host configuration immediately and persist across reboots.
[group('nixos')]
switch host=`hostname --short`:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild switch "${opts[@]}" --flake path:.#"{{host}}"

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
  @just gc-old "{{days}}"
  @just optimise-store
  @sudo nixos-rebuild test --flake .#"{{host}}"
  @sudo nixos-rebuild switch --flake .#"{{host}}"
