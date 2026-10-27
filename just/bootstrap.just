# Add the current NixOS machine to this repository.
[group('bootstrap')]
bootstrap-host hostname mode="auto":
  @./scripts/bootstrap-host.sh "{{hostname}}" "{{mode}}"

# Install multi-user Nix on macOS.
[group('bootstrap')]
bootstrap-macos:
  @./scripts/bootstrap-macos.sh
