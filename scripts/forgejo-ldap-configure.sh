#!/usr/bin/env bash
set -euo pipefail

secret_path='/srv/forgejo/ldap-bind-password'
if [[ $(id -un) != forgejo || ! -s $secret_path ]]; then
    echo 'Voer dit uit als forgejo met een bindwachtwoord op de persistente disk.' >&2
    exit 1
fi

if ! systemctl is-active --quiet forgejo; then
    echo 'Forgejo draait niet.' >&2
    exit 1
fi
exec_start=$(systemctl show -p ExecStart --value forgejo)
if [[ ! $exec_start =~ ^\{[[:space:]]path=([^[:space:];]+) ]]; then
    echo 'Kan de Forgejo-binary niet uit de systemd-unit halen.' >&2
    exit 1
fi
forgejo_bin=${BASH_REMATCH[1]}
forgejo_cmd=(
    "$forgejo_bin"
    --work-path /srv/forgejo/forgejo
    --config /srv/forgejo/forgejo/custom/conf/app.ini
)

auth_list=$("${forgejo_cmd[@]}" admin auth list)
mapfile -t source_ids < <(awk -F '\t' '$2 == "FreeIPA" { print $1 }' <<<"$auth_list")
if [[ ${#source_ids[@]} -gt 1 ]]; then
    echo 'Meerdere FreeIPA-aanmeldbronnen gevonden; pas ze eerst handmatig aan.' >&2
    exit 1
fi

auth_args=(
    --name FreeIPA
    --active
    --security-protocol ldaps
    --host ldap.powerlan.empire
    --port 636
    --user-search-base 'cn=users,cn=accounts,dc=powerlan,dc=empire'
    --user-filter '(&(uid=%s)(memberOf=cn=grp-forgejo-user,cn=groups,cn=accounts,dc=powerlan,dc=empire))'
    --admin-filter '(memberOf=cn=grp-forgejo-admin,cn=groups,cn=accounts,dc=powerlan,dc=empire)'
    --allow-deactivate-all
    --username-attribute uid
    --firstname-attribute givenName
    --surname-attribute sn
    --email-attribute mail
    --bind-dn 'uid=forgejo-reader,cn=sysaccounts,cn=etc,dc=powerlan,dc=empire'
    --bind-password "$(tr -d '\n' <"$secret_path")"
    --attributes-in-bind
    --synchronize-users
)

if [[ ${#source_ids[@]} -eq 0 ]]; then
    "${forgejo_cmd[@]}" admin auth add-ldap "${auth_args[@]}"
else
    "${forgejo_cmd[@]}" admin auth update-ldap --id "${source_ids[0]}" "${auth_args[@]}"
fi
"${forgejo_cmd[@]}" admin auth list
