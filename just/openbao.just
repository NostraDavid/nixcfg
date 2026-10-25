# Build and exercise real OpenBao and LDAP, without contacting production.
[group('openbao')]
openbao-check:
  @nix build path:.#checks.x86_64-linux.openbao --no-link --print-build-logs
  @just app-vm-check openbao
  @python3 checks/test-freeipa-policy.py

[group('openbao')]
openbao-image-check:
  @nix build path:.#checks.x86_64-linux.openbao-image --no-link --print-build-logs

[group('openbao')]
openbao-vm-init:
  @tofu -chdir=infra/openbao init

[group('openbao')]
openbao-vm-plan:
  @image_dir="$(nix build path:.#openbao-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" TF_VAR_image_path="$image_dir/nixos.qcow2" tofu -chdir=infra/openbao plan

[group('openbao')]
openbao-vm-apply:
  @image_dir="$(nix build path:.#openbao-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" TF_VAR_image_path="$image_dir/nixos.qcow2" tofu -chdir=infra/openbao apply

# Create the independent recovery key on this workstation, never on Proxmox.
[group('openbao')]
openbao-recovery-setup:
  @nix shell path:.#legacyPackages.x86_64-linux.age --command python3 scripts/openbao-maintain.py setup

# Provision only the three service accounts and the restricted password-write ACIs.
[group('openbao')]
openbao-directory-bootstrap:
  @nix shell path:.#legacyPackages.x86_64-linux.krb5 path:.#legacyPackages.x86_64-linux.openldap --command python3 scripts/freeipa-policy.py bootstrap-openbao

# Initialize after the new VM's SSH fingerprint and independent recovery key are verified.
[group('openbao')]
openbao-initialize:
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n install -m 0644 /dev/stdin /srv/openbao/ops/recipient' < "$HOME/.local/state/nixcfg/openbao/recipient"
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n openbao-ops init --recipient-file /srv/openbao/ops/recipient'
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n cat /srv/openbao/ops/recovery.age' > "$HOME/.local/state/nixcfg/openbao/initial-recovery.tar.age"

[group('openbao')]
openbao-tls:
  @python3 scripts/openbao-maintain.py tls

# The directory bootstrap creates this initial credential; OpenBao rotates it once imported.
[group('openbao')]
openbao-configure:
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n install -m 0600 /dev/stdin /srv/openbao/ops/rotator-password' < "$HOME/.local/state/nixcfg/openbao-rotator-password"
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n openbao-ops configure --ldap-password-file /srv/openbao/ops/rotator-password && sudo -n rm /srv/openbao/ops/rotator-password'

# Install both consumers before activating either password rotation.
[group('openbao')]
openbao-enroll:
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n openbao-ops enroll forgejo-reader && sudo -n openbao-ops enroll proxmox-reader'
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n cat /srv/openbao/ops/forgejo-reader-credentials.json' | ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.110 'sudo -n install -d -m 0700 /srv/forgejo/openbao-consumer && sudo -n install -m 0600 /dev/stdin /srv/forgejo/openbao-consumer/credentials.json'
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n cat /srv/openbao/ops/proxmox-reader-credentials.json' | ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes root@192.168.2.100 'install -d -m 0700 /var/lib/openbao-consumer && install -m 0600 /dev/stdin /var/lib/openbao-consumer/credentials.json'
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes root@192.168.2.100 'install -m 0600 /dev/stdin /usr/local/lib/openbao.py' < scripts/openbao.py
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes root@192.168.2.100 'bash -s' < scripts/openbao-install-proxmox.sh

[group('openbao')]
openbao-activate:
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n openbao-ops activate forgejo-reader && sudo -n openbao-ops activate proxmox-reader'
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.110 'sudo -n systemctl start openbao-consumer.service'
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes root@192.168.2.100 'systemctl start openbao-consumer.service'
  @ssh -F /dev/null -o BatchMode=yes -o StrictHostKeyChecking=yes david@192.168.2.112 'sudo -n openbao-ops finalize && sudo -n openbao-ops snapshot'
  @nix shell path:.#legacyPackages.x86_64-linux.age --command python3 scripts/openbao-maintain.py backup
  @touch "$HOME/.local/state/nixcfg/openbao/enabled"

[group('openbao')]
openbao-health:
  @python3 scripts/openbao-maintain.py check
