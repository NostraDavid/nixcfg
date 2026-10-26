# Keep these 30-day windows aligned with https://forgejo.org/docs/v17.0/admin/release-schedule/.
[private]
forgejo-support-warning today=`date -u +%F`:
  @today={{quote(today)}}; \
  if [[ "$today" < "2026-09-29" ]]; then exit 0; fi; \
  version="$(nix eval --raw path:.#nixosConfigurations.forgejo.config.services.forgejo.package.version 2>/dev/null)" || version=unknown; \
  case "$version" in \
    15.*) warning_from=2027-06-15; eol=2027-07-15 ;; \
    16.*) warning_from=2026-09-29; eol=2026-10-29 ;; \
    17.*) warning_from=2026-12-29; eol=2027-01-28 ;; \
    18.*) warning_from=2027-03-30; eol=2027-04-29 ;; \
    19.*) warning_from=2028-06-13; eol=2028-07-13 ;; \
    *) red="$(printf '\033[1;31m')"; reset="$(printf '\033[0m')"; printf '%sWARNING: check the support deadline for Forgejo %s before updating or switching.%s\n' "$red" "$version" "$reset"; exit 0 ;; \
  esac; \
  if [[ "$today" < "$warning_from" ]]; then exit 0; fi; \
  red="$(printf '\033[1;31m')"; reset="$(printf '\033[0m')"; \
  if [[ "$today" > "$eol" ]]; then state='is past support'; else state='support ends'; fi; \
  printf '%sWARNING: Forgejo %s %s on %s. Plan an upgrade now.%s\n' "$red" "$version" "$state" "$eol" "$reset"

# Evaluate an app VM configuration, including untracked local files.
[group('proxmox')]
app-vm-check host:
  @nix eval path:.#nixosConfigurations."{{host}}".config.system.build.toplevel.drvPath

# Evaluate the Proxmox app VM configurations.
[group('proxmox')]
app-vms-check:
  @just app-vm-check homepage
  @just app-vm-check apps
  @just app-vm-check forgejo
  @just app-vm-check proxy
  @just app-vm-check certs
  @just app-vm-check openbao
  @just app-vm-check k3s

# Deploy an app VM configuration to a remote NixOS guest.
[group('proxmox')]
app-vm-deploy host target:
  @if [ "{{host}}" = "forgejo" ]; then just forgejo-support-warning; fi; \
  nixos-rebuild switch --flake path:.#"{{host}}" --target-host "{{target}}" --use-remote-sudo

# Deploy Homepage on its dedicated VM.
[group('proxmox')]
deploy-homepage target="david@192.168.2.103":
  @just app-vm-deploy homepage "{{target}}"

# Check monitoring freshness, credential boundaries and the local status API.
[group('proxmox')]
homepage-monitor-test:
  @python3 checks/test-homepage-monitor.py

# Deploy the declarative K3s node after its initial VM installation.
[group('proxmox')]
deploy-k3s target="david@192.168.2.106":
  @just app-vm-deploy k3s "{{target}}"

# Check that identity setup refuses conflicting clients and groups before writing.
[group('proxmox')]
k3s-headlamp-test:
  @python3 checks/test-headlamp-identity.py

# Verify the public OIDC issuer used by the Headlamp dashboard.
[group('proxmox')]
k3s-headlamp-check:
  @nix run path:.#headlamp-identity -- check --ca certs/forgejo-ca.crt

# Check the POC health endpoint and secret redaction.
[group('proxmox')]
k3s-poc-test:
  @python3 checks/test-k3s-poc.py

# Deploy the shared apps VM configuration.
[group('proxmox')]
deploy-apps target="david@apps":
  @just app-vm-deploy apps "{{target}}"

# Deploy the Forgejo VM configuration.
[group('proxmox')]
deploy-forgejo target="david@192.168.2.110":
  @just app-vm-deploy forgejo "{{target}}"

# Deploy the shared proxy VM configuration.
[group('proxmox')]
deploy-proxy target="david@192.168.2.111":
  @just app-vm-deploy proxy "{{target}}"

# Deploy the dedicated certificate authority and download portal.
[group('proxmox')]
deploy-certs target="david@192.168.2.113":
  @just app-vm-deploy certs "{{target}}"

# Check the current Pi-hole certificate, its publication and all HTTPS identities.
[group('proxmox')]
pihole-tls-check:
  @python3 ./scripts/pihole-tls.py check --ca ./certs/forgejo-ca.crt

# Exercise certificate validation, idempotence and failed-install recovery locally.
[group('proxmox')]
pihole-tls-test:
  @python3 ./checks/test-pihole-tls.py

[group('proxmox')]
deploy-openbao target="david@192.168.2.112":
  @just app-vm-deploy openbao "{{target}}"

# Verify the shared CA files and their inclusion in every NixOS host.
[group('proxmox')]
internal-pki-check:
  @cd certs && sha256sum -c SHA256SUMS
  @openssl verify -CAfile certs/freeipa.crt certs/freeipa.crt
  @openssl verify -CAfile certs/forgejo-ca.crt certs/forgejo-ca.crt
  @openssl x509 -in certs/freeipa.crt -checkend 0 -noout
  @openssl x509 -in certs/forgejo-ca.crt -checkend 0 -noout
  @nix eval --json path:.#nixosConfigurations --apply 'hosts: builtins.mapAttrs (_: host: let files = map builtins.baseNameOf host.config.security.pki.certificateFiles; in assert builtins.elem "freeipa.crt" files; assert builtins.elem "forgejo-ca.crt" files; true) hosts'

# Verify the deployed CA page and byte-for-byte downloads.
[group('proxmox')]
internal-pki-site-check:
  @for file in freeipa.crt forgejo-ca.crt fingerprints.txt SHA256SUMS; do cmp "certs/$file" <(curl --fail --silent --show-error "http://192.168.2.113/$file"); done
  @curl --fail --silent --show-error http://192.168.2.113/ | grep 'Interne certificaten' >/dev/null
  @test "$(curl --silent --output /dev/null --write-out '%{http_code}' http://192.168.2.113/root.key)" = 404

# Verify versioned bundles, PEM trust, retries and retained releases.
[group('proxmox')]
internal-pki-bundle-check:
  @python3 checks/test-internal-pki-bundle.py

# Check the Forgejo/FreeIPA LDAP prerequisites without changing accounts.
[group('proxmox')]
forgejo-ldap-check:
  @nix shell nixpkgs#openldap --command ./scripts/forgejo-ldap-bootstrap.sh --check

# Create the restricted FreeIPA bind account and configure Forgejo via LDAPS.
[group('proxmox')]
forgejo-ldap-bootstrap:
  @nix shell nixpkgs#openldap nixpkgs#krb5 --command ./scripts/forgejo-ldap-bootstrap.sh

# Validate the Git-owned FreeIPA group policy without connecting to FreeIPA.
[group('proxmox')]
freeipa-policy-validate:
  @python3 ./scripts/freeipa-policy.py validate

# Show or apply exact group membership using an interactive admin Kerberos ticket.
[group('proxmox')]
freeipa-policy-plan:
  @nix shell nixpkgs#freeipa nixpkgs#krb5 nixpkgs#openldap --command python3 ./scripts/freeipa-policy.py plan

[group('proxmox')]
freeipa-policy-apply:
  @nix shell nixpkgs#freeipa nixpkgs#krb5 nixpkgs#openldap --command python3 ./scripts/freeipa-policy.py apply

[group('proxmox')]
freeipa-policy-check:
  @nix shell nixpkgs#freeipa nixpkgs#krb5 nixpkgs#openldap --command python3 ./scripts/freeipa-policy.py check

# Create the dedicated Proxmox LDAP search account and a local, untracked password file.
[group('proxmox')]
freeipa-proxmox-reader-bootstrap:
  @nix shell nixpkgs#freeipa nixpkgs#krb5 nixpkgs#openldap --command python3 ./scripts/freeipa-policy.py bootstrap-proxmox-reader

# Manage Proxmox's FreeIPA realm and ACLs in a separate, privileged Tofu stack.
[group('tofu')]
tofu-proxmox-access-init:
  @tofu -chdir=infra/proxmox-access init

[group('tofu')]
tofu-proxmox-access-tfvars:
  @cp -n infra/proxmox-access/terraform.tfvars.example infra/proxmox-access/terraform.tfvars
  @${EDITOR:-nano} infra/proxmox-access/terraform.tfvars

[group('tofu')]
tofu-proxmox-access-check:
  @tofu fmt -check infra/proxmox-access
  @tofu -chdir=infra/proxmox-access validate

[group('tofu')]
tofu-proxmox-access-plan:
  @SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" tofu -chdir=infra/proxmox-access plan

[group('tofu')]
tofu-proxmox-access-apply:
  @SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" tofu -chdir=infra/proxmox-access apply

# Format a Homepage state disk with the expected filesystem label.
[group('proxmox')]
format-homepage-data device:
  @sudo mkfs.ext4 -L homepage-data "{{device}}"

# Format the apps PostgreSQL state disk with the expected filesystem label.
[group('proxmox')]
format-apps-postgres device:
  @sudo mkfs.ext4 -L apps-postgres "{{device}}"

# Format the apps upload/state disk with the expected filesystem label.
[group('proxmox')]
format-apps-data device:
  @sudo mkfs.ext4 -L apps-data "{{device}}"

# Initialize OpenTofu for Proxmox VM management.
[group('tofu')]
tofu-proxmox-init:
  @tofu -chdir=infra/proxmox init

# Create a local Proxmox OpenTofu variables file from the example.
[group('tofu')]
tofu-proxmox-tfvars:
  @cp -n infra/proxmox/terraform.tfvars.example infra/proxmox/terraform.tfvars
  @${EDITOR:-nano} infra/proxmox/terraform.tfvars

# Format the Proxmox OpenTofu files.
[group('tofu')]
tofu-proxmox-fmt:
  @tofu fmt -recursive infra/proxmox

# Check Proxmox OpenTofu formatting.
[group('tofu')]
tofu-proxmox-fmt-check:
  @tofu fmt -check -recursive infra/proxmox

# Validate the Proxmox OpenTofu configuration.
[group('tofu')]
tofu-proxmox-validate:
  @tofu -chdir=infra/proxmox validate

# Show effective Proxmox permissions for the configured API token.
[group('tofu')]
tofu-proxmox-permissions:
  @./scripts/proxmox-permissions.sh

# Run non-network OpenTofu checks for the Proxmox stack.
[group('tofu')]
tofu-proxmox-check:
  @just tofu-proxmox-fmt-check
  @just tofu-proxmox-validate

# Plan Proxmox VM changes.
[group('tofu')]
tofu-proxmox-plan:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; certs_image_dir="$(nix build path:.#certs-image --no-link --print-out-paths)"; homepage_image_dir="$(nix build path:.#homepage-image --no-link --print-out-paths)"; test -s "$forgejo_image_dir/nixos.qcow2"; test -s "$proxy_image_dir/nixos.qcow2"; SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" TF_VAR_certs_image_path="$certs_image_dir/nixos.qcow2" TF_VAR_homepage_image_path="$homepage_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox plan

# Build the NixOS image and apply Proxmox VM changes.
[group('tofu')]
tofu-proxmox-apply:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; certs_image_dir="$(nix build path:.#certs-image --no-link --print-out-paths)"; homepage_image_dir="$(nix build path:.#homepage-image --no-link --print-out-paths)"; test -s "$forgejo_image_dir/nixos.qcow2"; test -s "$proxy_image_dir/nixos.qcow2"; SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" TF_VAR_certs_image_path="$certs_image_dir/nixos.qcow2" TF_VAR_homepage_image_path="$homepage_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox apply

# Show OpenTofu-managed Proxmox VM outputs.
[group('tofu')]
tofu-proxmox-output:
  @tofu -chdir=infra/proxmox output

# List resources in the Proxmox OpenTofu state.
[group('tofu')]
tofu-proxmox-state:
  @tofu -chdir=infra/proxmox state list

# Plan destroying OpenTofu-managed Proxmox resources.
[group('tofu')]
tofu-proxmox-plan-destroy:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; certs_image_dir="$(nix build path:.#certs-image --no-link --print-out-paths)"; homepage_image_dir="$(nix build path:.#homepage-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" TF_VAR_certs_image_path="$certs_image_dir/nixos.qcow2" TF_VAR_homepage_image_path="$homepage_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox plan -destroy

# Destroy OpenTofu-managed Proxmox resources.
[group('tofu')]
tofu-proxmox-destroy:
  @forgejo_image_dir="$(nix build path:.#forgejo-image --no-link --print-out-paths)"; proxy_image_dir="$(nix build path:.#proxy-image --no-link --print-out-paths)"; certs_image_dir="$(nix build path:.#certs-image --no-link --print-out-paths)"; homepage_image_dir="$(nix build path:.#homepage-image --no-link --print-out-paths)"; SSL_CERT_FILE="$PWD/hosts/physical/wodan/certs/proxmox.crt" TF_VAR_forgejo_image_path="$forgejo_image_dir/nixos.qcow2" TF_VAR_proxy_image_path="$proxy_image_dir/nixos.qcow2" TF_VAR_certs_image_path="$certs_image_dir/nixos.qcow2" TF_VAR_homepage_image_path="$homepage_image_dir/nixos.qcow2" tofu -chdir=infra/proxmox destroy
