#!/usr/bin/env bash
set -euo pipefail

[[ $(id -u) == 0 ]] || {
    echo 'Run this on the Proxmox host as root.' >&2
    exit 1
}
command -v ldapwhoami >/dev/null || {
    echo 'Install ldap-utils before enabling the consumer.' >&2
    exit 1
}
test -s /usr/local/lib/openbao.py
test -s /var/lib/openbao-consumer/credentials.json
chmod 0600 /var/lib/openbao-consumer/credentials.json
install -d -m 0755 /etc/openbao-consumer
cat >/etc/openbao-consumer/config.json <<'EOF'
{"service":"proxmox-reader","address":"https://192.168.2.112"}
EOF
cat >/etc/systemd/system/openbao-consumer.service <<'EOF'
[Unit]
Description=Apply the current OpenBao LDAP credential to the FreeIPA realm
Wants=network-online.target
After=network-online.target pve-cluster.service
Requires=pve-cluster.service
ConditionPathExists=/var/lib/openbao-consumer/credentials.json

[Service]
Type=oneshot
ExecStart=/usr/bin/python3 /usr/local/lib/openbao.py consume --config /etc/openbao-consumer/config.json --state /var/lib/openbao-consumer
UMask=0077
PrivateTmp=true
ProtectHome=true
TimeoutStartSec=3min
EOF
cat >/etc/systemd/system/openbao-consumer.timer <<'EOF'
[Unit]
Description=Reconcile the Proxmox LDAP password every minute

[Timer]
OnBootSec=90s
OnUnitInactiveSec=1min
Unit=openbao-consumer.service

[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now openbao-consumer.timer
