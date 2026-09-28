#!/usr/bin/env bash
set -euo pipefail

if [[ $# -gt 1 || ($# -eq 1 && $1 != --check) ]]; then
    echo 'Usage: forgejo-ldap-bootstrap.sh [--check]' >&2
    exit 2
fi

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ca_cert="$repo_root/hosts/wodan/certs/freeipa.crt"
ldap_url='ldaps://ldap.powerlan.empire'
users_base='cn=users,cn=accounts,dc=powerlan,dc=empire'
group_dn='cn=grp-forgejo-user,cn=groups,cn=accounts,dc=powerlan,dc=empire'
bind_dn='uid=forgejo-reader,cn=sysaccounts,cn=etc,dc=powerlan,dc=empire'
forgejo_target='david@192.168.2.110'
secret_path='/srv/forgejo/ldap-bind-password'

for required_command in ldapadd ldapsearch ldapwhoami openssl ssh; do
    command -v "$required_command" >/dev/null || {
        echo "Ontbrekend commando: $required_command" >&2
        exit 1
    }
done

export LDAPTLS_CACERT="$ca_cert"
group_result=$(ldapsearch -x -LLL -H "$ldap_url" -s base -b "$group_dn" '(objectClass=*)' dn)
if ! grep -Fxq "dn: $group_dn" <<<"$group_result"; then
    echo "FreeIPA-groep ontbreekt: $group_dn" >&2
    exit 1
fi
ssh -o BatchMode=yes "$forgejo_target" \
    'mountpoint -q /srv/forgejo && systemctl is-active --quiet forgejo'

if [[ ${1:-} == --check ]]; then
    echo 'FreeIPA LDAPS, Forgejo en de toegangsgroep zijn bereikbaar.'
    exit 0
fi

umask 077
temp_dir=$(mktemp -d)
trap 'rm -rf -- "$temp_dir"' EXIT
password_file="$temp_dir/ldap-bind-password"

if ssh -o BatchMode=yes "$forgejo_target" "sudo test -s $secret_path"; then
    ssh -o BatchMode=yes "$forgejo_target" "sudo cat $secret_path" >"$password_file"
else
    openssl rand -base64 48 >"$password_file"
    ssh -o BatchMode=yes "$forgejo_target" \
        "sudo install -m 0600 -o forgejo -g forgejo /dev/stdin $secret_path" \
        <"$password_file"
fi

if [[ $(wc -c <"$password_file") -lt 48 ]]; then
    echo 'Het opgeslagen bindwachtwoord is onvolledig.' >&2
    exit 1
fi

if ! ldapwhoami -x -H "$ldap_url" -D "$bind_dn" -y "$password_file" >/dev/null 2>&1; then
    cat >"$temp_dir/forgejo-reader.ldif" <<EOF
dn: $bind_dn
changetype: add
objectClass: account
objectClass: simpleSecurityObject
uid: forgejo-reader
userPassword: $(tr -d '\n' <"$password_file")
passwordExpirationTime: 20380119031407Z
nsIdleTimeout: 0
EOF
    echo 'Voer nu zelf het FreeIPA Directory Manager-wachtwoord in bij de LDAP-prompt.'
    ldapadd -x -H "$ldap_url" -D 'cn=Directory Manager' -W \
        -f "$temp_dir/forgejo-reader.ldif"
fi

ldapwhoami -x -H "$ldap_url" -D "$bind_dn" -y "$password_file" >/dev/null
allowed_filter="(&(uid=nostradavid)(memberOf=$group_dn))"
allowed_result=$(ldapsearch -x -LLL -H "$ldap_url" -D "$bind_dn" -y "$password_file" \
    -b "$users_base" "$allowed_filter" dn mail)
if ! grep -Fxq "dn: uid=nostradavid,$users_base" <<<"$allowed_result"; then
    echo 'Het bindaccount kan nostradavid niet via de Forgejo-groep vinden.' >&2
    exit 1
fi
if ! grep -Eq '^mail: .+' <<<"$allowed_result"; then
    echo 'Het bindaccount kan het e-mailadres van nostradavid niet lezen.' >&2
    exit 1
fi

denied_filter="(&(uid=ldap_tester)(memberOf=$group_dn))"
denied_user=$(ldapsearch -x -LLL -H "$ldap_url" -D "$bind_dn" -y "$password_file" \
    -s base -b "uid=ldap_tester,$users_base" '(objectClass=*)' dn)
if ! grep -Fxq "dn: uid=ldap_tester,$users_base" <<<"$denied_user"; then
    echo 'Kan de negatieve controle met ldap_tester niet uitvoeren.' >&2
    exit 1
fi
denied_result=$(ldapsearch -x -LLL -H "$ldap_url" -D "$bind_dn" -y "$password_file" \
    -b "$users_base" "$denied_filter" dn)
if grep -q '^dn:' <<<"$denied_result"; then
    echo 'ldap_tester staat onverwacht in de Forgejo-groep.' >&2
    exit 1
fi

ssh -o BatchMode=yes "$forgejo_target" 'sudo -u forgejo bash -s' \
    <"$repo_root/cmd/forgejo-ldap-configure.sh"
ssh -o BatchMode=yes "$forgejo_target" \
    'sudo systemctl restart forgejo && systemctl is-active --quiet forgejo'
echo 'FreeIPA-aanmeldbron geconfigureerd. Test nu het inloggen als nostradavid.'
