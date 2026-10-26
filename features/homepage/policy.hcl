path "services/data/homepage/proxmox" {
  capabilities = ["read"]
}
path "services/data/homepage/pihole" {
  capabilities = ["read"]
}
path "status/data/forgejo-reader" {
  capabilities = ["read"]
}
path "status/data/proxmox-reader" {
  capabilities = ["read"]
}
path "ldap/static-role/forgejo-reader" {
  capabilities = ["read"]
}
path "ldap/static-role/proxmox-reader" {
  capabilities = ["read"]
}
path "auth/token/revoke-self" {
  capabilities = ["update"]
}
