# Inspect the selected NixOS configuration from the flake.
nixos-show host=default_host:
  @nix flake show .#nixosConfigurations."{{host}}"

# Add the current NixOS machine to this repository.
bootstrap-host hostname mode="auto":
  @./cmd/bootstrap-host.sh "{{hostname}}" "{{mode}}"

# Test a host configuration temporarily; reverts after reboot.
test host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild test "${opts[@]}" --flake path:.#"{{host}}"

# Apply a host configuration immediately and persist across reboots.
switch host=`hostname --short`:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild switch "${opts[@]}" --flake path:.#"{{host}}"

# Stage a host configuration for the next boot only.
boot host=default_host:
  @opts=(); \
  if [ "{{host}}" = "frigg" ]; then opts+=(--option max-jobs 2 --option cores 4); fi; \
  sudo nixos-rebuild boot "${opts[@]}" --flake path:.#"{{host}}"

# Build a VM for the selected host configuration.
build-vm host=default_host:
  @nixos-rebuild build-vm --flake path:.#"{{host}}"

# Safer deploy when disk pressure is high.
switch-clean host=default_host days="14":
  @just gc-old "{{days}}"
  @just optimise-store
  @sudo nixos-rebuild test --flake .#"{{host}}"
  @sudo nixos-rebuild switch --flake .#"{{host}}"
