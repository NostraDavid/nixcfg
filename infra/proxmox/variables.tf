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
  description = "Allow the provider to connect to Proxmox with a self-signed TLS certificate."
  type        = bool
  default     = true
}

variable "node_name" {
  description = "Name of the Proxmox node that should host the VMs."
  type        = string
}

variable "datastore_id" {
  description = "Proxmox datastore for VM disks, for example local-lvm."
  type        = string
  default     = "local-lvm"
}

variable "network_bridge" {
  description = "Proxmox network bridge connected to the LAN."
  type        = string
  default     = "vmbr0"
}
