terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.104.0"
    }
  }
}
variable "endpoint" { type = string }
variable "api_token" {
  type      = string
  sensitive = true
}
variable "image_path" { type = string }
variable "node" { type = string }
variable "vmid" { type = number }
variable "address" { type = string }
variable "mac" { type = string }
variable "cores" { type = number }
variable "memory_mb" { type = number }
variable "system_disk_gb" { type = number }
variable "data_disk_gb" { type = number }

provider "proxmox" {
  endpoint  = var.endpoint
  api_token = var.api_token
  insecure  = false
}
resource "proxmox_virtual_environment_file" "image" {
  content_type = "import"
  datastore_id = "lab-store"
  node_name    = var.node
  source_file {
    path      = var.image_path
    file_name = "forgejo-lab.qcow2"
  }
}
resource "proxmox_virtual_environment_vm" "forgejo" {
  name       = "forgejo-lab"
  node_name  = var.node
  vm_id      = var.vmid
  started    = true
  on_boot    = true
  tags       = ["nixcfg-lab"]
  bios       = "seabios"
  machine    = "pc"
  boot_order = ["virtio0"]
  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }
  memory { dedicated = var.memory_mb }
  agent { enabled = true }
  operating_system { type = "l26" }
  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = var.mac
  }
  disk {
    datastore_id = "lab-store"
    interface    = "virtio0"
    import_from  = proxmox_virtual_environment_file.image.id
    size         = var.system_disk_gb
    file_format  = "qcow2"
    serial       = "forgejo-root"
  }
  disk {
    datastore_id = "lab-store"
    interface    = "virtio1"
    size         = var.data_disk_gb
    file_format  = "qcow2"
    serial       = "forgejo-state"
  }
  serial_device {}
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [disk[0].import_from]
    precondition {
      condition     = var.endpoint != "https://192.168.2.100:8006/" && var.node == "pve-lab"
      error_message = "This stack is exclusively for the local pve-lab node."
    }
  }
}
output "forgejo_url" { value = "http://${var.address}:3000/" }
