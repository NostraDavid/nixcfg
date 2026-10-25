output "openbao_vm" {
  description = "Dedicated OpenBao VM."
  value = {
    vm_id   = proxmox_virtual_environment_vm.openbao.vm_id
    started = proxmox_virtual_environment_vm.openbao.started
    address = "https://192.168.2.112"
  }
}
