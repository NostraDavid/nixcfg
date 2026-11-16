# Boot the production Nextcloud feature against synthetic LDAPS and test rotation.
[group('nextcloud')]
nextcloud-check:
  @nix build path:.#checks.x86_64-linux.nextcloud-ldap path:.#checks.x86_64-linux.openbao --no-link --print-build-logs
  @python3 checks/test-freeipa-policy.py
  @just app-vm-check nextcloud

[group('nextcloud')]
nextcloud-image:
  @nix build path:.#nextcloud-image --no-link --print-out-paths

[group('nextcloud')]
deploy-nextcloud target="david@192.168.2.115":
  @just app-vm-deploy nextcloud "{{target}}"
