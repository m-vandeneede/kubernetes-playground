resource "proxmox_vm_qemu" "cluster_vm" {
  for_each = {
    for k, v in local.cluster_vms : k => v
    if try(v.proxmox, false)
  }
  name        = each.key
  target_node = each.value.target_node.node_name
  bios        = "ovmf"
  vm_state    = "stopped" # Enable this later
  agent       = 1
  qemu_os     = "l26"
  memory      = each.value.memory
  balloon     = 0 # Unsupported by Talos
  scsihw      = "virtio-scsi-pci"
  tags        = "kubernetes,talos,${(each.value.controlplane ? "controlplane" : "worker")}"
  machine     = "q35"

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  network {
    id       = 0
    model    = "virtio"
    tag      = local.cluster_vlan
    bridge   = "vmbr0"
    firewall = false
  }

  rng {

  }

  disks {
    ide {
      ide0 {
        disk {
          backup     = false
          size       = each.value.disk_size
          emulatessd = true
          format     = "raw"
          storage    = each.value.disk_pool
          asyncio    = "io_uring"
          discard    = true
        }
      }
      ide1 {
        cdrom {
          iso = each.value.target_node.iso_installation
        }
      }
    }
  }

  efidisk {
    efitype           = "4m"
    storage           = each.value.disk_pool
    pre_enrolled_keys = false # No secure boot, so this is not needed
  }
}
