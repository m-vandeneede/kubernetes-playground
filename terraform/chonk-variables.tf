variable "chonk_disk_pool" {
  description = "Proxmox storage ID for CHONK's pve/data LVM-thin pool. Must be registered before deployment; do not use fast/local on the small root filesystem."
  type        = string
  default     = "local-lvm"

  validation {
    condition     = !contains(["fast", "local", ""], var.chonk_disk_pool)
    error_message = "Use storage backed by CHONK's large thin pool, not its fast/local root filesystem."
  }
}

variable "chonk_vm_state" {
  description = "Desired power state of the deployed CHONK VMs. Override to stopped only for explicitly reviewed maintenance or new provisioning."
  type        = string
  default     = "running"

  validation {
    condition     = contains(["stopped", "running"], var.chonk_vm_state)
    error_message = "CHONK VM state must be stopped or running."
  }
}
