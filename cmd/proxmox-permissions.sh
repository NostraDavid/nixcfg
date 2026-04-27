#!/usr/bin/env bash
set -euo pipefail

tfvars="infra/proxmox/terraform.tfvars"
endpoint="https://192.168.2.100:8006/"

if [[ ! -f "$tfvars" ]]; then
  echo "Missing $tfvars. Run: just tofu-proxmox-tfvars" >&2
  exit 1
fi

configured_endpoint="$(awk -F '"' '/proxmox_endpoint/ {print $2}' "$tfvars" 2>/dev/null || true)"
if [[ -n "$configured_endpoint" ]]; then
  endpoint="$configured_endpoint"
fi

token="$(awk -F '"' '/proxmox_api_token/ {print $2}' "$tfvars")"

curl -fsSk \
  -H "Authorization: PVEAPIToken=${token}" \
  "${endpoint%/}/api2/json/access/permissions" \
  | jq -r '
      .data
      | to_entries
      | if length == 0 then
          "No effective permissions returned for this token."
        else
          map("\(.key): \(.value | keys | sort | join(", "))")
          | .[]
        end
    '
