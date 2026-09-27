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
  on_boot = false

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

resource "proxmox_virtual_environment_file" "forgejo_image" {
  content_type = "import"
  datastore_id = "local"
  node_name    = var.node_name
  overwrite    = false

  source_file {
    path      = var.forgejo_image_path
    file_name = "forgejo-${substr(filesha256(var.forgejo_image_path), 0, 12)}.qcow2"
    checksum  = filesha256(var.forgejo_image_path)
  }
}

resource "proxmox_virtual_environment_vm" "forgejo" {
  name        = "prd-svc-forgejo-01"
  description = "Forgejo Git service VM. NixOS system and persistent Forgejo data use separate disks."
  node_name   = var.node_name
  vm_id       = 110

  started    = true
  on_boot    = true
  bios       = "seabios"
  boot_order = ["virtio0"]

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
    datastore_id = var.forgejo_datastore_id
    interface    = "virtio0"
    import_from  = proxmox_virtual_environment_file.forgejo_image.id
    size         = 32
    file_format  = "raw"
    serial       = "forgejo-root"
  }

  disk {
    datastore_id = var.forgejo_datastore_id
    interface    = "virtio1"
    size         = 64
    file_format  = "raw"
    serial       = "forgejo-state"
  }

  serial_device {}

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [disk[0].import_from]
  }
}
