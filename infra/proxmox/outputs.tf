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
