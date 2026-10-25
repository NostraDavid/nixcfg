variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.2.100:8006/"
}

variable "proxmox_api_token" {
  description = "Existing Proxmox provisioning token; keep its value outside Git."
  type        = string
  sensitive   = true
}

variable "node_name" {
  type    = string
  default = "POwerMonolith"
}

variable "datastore_id" {
  type    = string
  default = "vm_storage_1"
}

variable "network_bridge" {
  type    = string
  default = "vmbr0"
}

variable "image_path" {
  description = "Absolute path to the Nix-built OpenBao QCOW2 image."
  type        = string
}
