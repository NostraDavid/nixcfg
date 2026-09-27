output "app_vms" {
  description = "VMs managed by this OpenTofu stack."
  value = {
    for name, vm in proxmox_virtual_environment_vm.app : name => {
      id      = vm.id
      vm_id   = vm.vm_id
      started = vm.started
    }
  }
}

output "forgejo_vm" {
  description = "Forgejo VM managed by this OpenTofu stack."
  value = {
    id      = proxmox_virtual_environment_vm.forgejo.id
    vm_id   = proxmox_virtual_environment_vm.forgejo.vm_id
    started = proxmox_virtual_environment_vm.forgejo.started
  }
}

output "proxy_vm" {
  description = "Shared proxy VM managed by this OpenTofu stack."
  value = {
    id      = proxmox_virtual_environment_vm.proxy.id
    vm_id   = proxmox_virtual_environment_vm.proxy.vm_id
    started = proxmox_virtual_environment_vm.proxy.started
  }
}
