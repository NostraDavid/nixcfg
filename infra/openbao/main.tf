terraform {
  required_version = ">= 1.6.0"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "= 0.104.0"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
}

resource "proxmox_virtual_environment_file" "openbao_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.node_name
  overwrite    = false

  source_file {
    path      = var.image_path
    file_name = "openbao-${substr(filesha256(var.image_path), 0, 12)}.qcow2"
    checksum  = filesha256(var.image_path)
  }
}

resource "proxmox_virtual_environment_vm" "openbao" {
  name        = "prd-svc-secrets-01"
  description = "OpenBao secrets service; replaceable NixOS root and persistent vault, seal and recovery disk."
  node_name   = var.node_name
  vm_id       = 112
  started     = true
  on_boot     = true
  bios        = "seabios"
  boot_order  = ["virtio0"]

  agent {
    enabled = true
  }
  cpu {
    cores = 2
    type  = "host"
  }
  memory {
    dedicated = 4096
  }
  operating_system {
    type = "l26"
  }
  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    import_from  = proxmox_virtual_environment_file.openbao_image.id
    size         = 16
    file_format  = "raw"
    serial       = "openbao-root"
  }
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio1"
    size         = 16
    file_format  = "raw"
    serial       = "openbao-state"
  }
  serial_device {}
  lifecycle {
    prevent_destroy = true
    ignore_changes  = [disk[0].import_from]
  }
}
