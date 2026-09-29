# Add the current NixOS machine to this repository.
[group('bootstrap')]
bootstrap-host hostname mode="auto":
  @./cmd/bootstrap-host.sh "{{hostname}}" "{{mode}}"
