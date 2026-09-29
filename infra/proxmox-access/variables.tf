variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.2.100:8006/"
}

variable "proxmox_api_token" {
  description = "Dedicated access-management token whose backing user can grant Administrator on /."
  type        = string
  sensitive   = true
}

variable "ldap_bind_password_path" {
  description = "Local password file created by the Proxmox LDAP reader bootstrap."
  type        = string
  default     = "~/.local/state/nixcfg/proxmox-ldap-bind-password"
}
