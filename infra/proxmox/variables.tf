variable "proxmox_endpoint" {
  description = "Proxmox API root URL for the bpg/proxmox provider. The raw Proxmox API lives under /api2/json, but this provider expects the root URL."
  type        = string
  default     = "https://192.168.2.100:8006/"
}

variable "proxmox_api_token" {
  description = "Proxmox API token in the form user@realm!token-id=secret."
  type        = string
  sensitive   = true
}

variable "proxmox_insecure" {
  description = "Allow an unverified Proxmox TLS certificate. Keep false after installing the internal CA on the operator host."
  type        = bool
  default     = false
}

variable "node_name" {
  description = "Name of the Proxmox node that should host the VMs."
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore for VM disks."
  type        = string
  default     = "local"
}

variable "network_bridge" {
  description = "Proxmox network bridge connected to the LAN."
  type        = string
  default     = "vmbr0"
}
