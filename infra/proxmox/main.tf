terraform {
  required_version = ">= 1.6.0"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.77"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_endpoint
  api_token = var.proxmox_api_token
  insecure  = var.proxmox_insecure
}

locals {
  app_vms = {
    homepage = {
      vm_id       = 210
      description = "Homepage dashboard VM. OS managed by NixOS; state on homepage-data disk."
      cpu_cores   = 1
      memory_mb   = 1024
      disks = [
        {
          datastore_id = var.datastore_id
          interface    = "scsi0"
          size         = 16
        },
        {
          datastore_id = var.datastore_id
          interface    = "scsi1"
          size         = 8
        },
      ]
    }

    apps = {
      vm_id       = 211
      description = "Shared self-hosted apps VM. OS managed by NixOS; PostgreSQL and uploads on separate disks."
      cpu_cores   = 2
      memory_mb   = 4096
      disks = [
        {
          datastore_id = var.datastore_id
          interface    = "scsi0"
          size         = 32
        },
        {
          datastore_id = var.datastore_id
          interface    = "scsi1"
          size         = 32
        },
        {
          datastore_id = var.datastore_id
          interface    = "scsi2"
          size         = 64
        },
      ]
    }
  }
}

resource "proxmox_virtual_environment_vm" "app" {
  for_each = local.app_vms

  name        = each.key
  description = each.value.description
  node_name   = var.node_name
  vm_id       = each.value.vm_id

  started = false

  agent {
    enabled = true
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  operating_system {
    type = "l26"
  }

  scsi_hardware = "virtio-scsi-single"

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  dynamic "disk" {
    for_each = each.value.disks

    content {
      datastore_id = disk.value.datastore_id
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = "raw"
    }
  }
}
