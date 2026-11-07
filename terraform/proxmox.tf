resource "proxmox_vm_qemu" "cluster_vm" {
  for_each = {
    for k, v in local.cluster_vms : k => v
    if try(v.proxmox, false)
  }
  name        = each.key
  target_node = each.value.target_node.node_name
  bios        = "ovmf"
  vm_state    = try(each.value.vm_state, var.vm_state)
  boot        = try(each.value.boot, null)
  agent       = 1
  qemu_os     = "l26"
  memory      = each.value.memory
  balloon     = 0 # Unsupported by Talos
  scsihw      = "virtio-scsi-pci"
  tags        = "kubernetes,talos,${(each.value.controlplane ? "controlplane" : "worker")}"
  machine     = "q35"
  skip_ipv6   = true

  dynamic "startup_shutdown" {
    for_each = try(each.value.startup_shutdown, null) != null ? [each.value.startup_shutdown] : []
    content {
      order            = startup_shutdown.value.order
      shutdown_timeout = startup_shutdown.value.shutdown_timeout
      startup_delay    = startup_shutdown.value.startup_delay
    }
  }

  # Keep PCI assignment in the shared VM resource; only opted-in nodes get a device.
  dynamic "pcis" {
    for_each = try(each.value.gpu_pci_mapping, null) != null ? [each.value.gpu_pci_mapping] : []
    content {
      pci0 {
        mapping {
          mapping_id  = pcis.value
          pcie        = true
          primary_gpu = false # Retain the virtual display for the Talos console.
          rombar      = true
        }
      }
    }
  }

  # Optional serial adapters, kept in the shared VM resource like PCI passthrough.
  dynamic "usbs" {
    for_each = try(each.value.usb_devices, null) != null ? [each.value.usb_devices] : []
    content {
      usb0 {
        device {
          device_id = usbs.value.zigbee
          usb3      = false
        }
      }
      usb1 {
        device {
          device_id = usbs.value.printer
          usb3      = false
        }
      }
    }
  }

  cpu {
    cores = each.value.cores
    type  = "host"
  }

  network {
    id    = 0
    model = "virtio"
    #tag      = local.cluster_vlan
    bridge   = "vmbr0"
    firewall = false
  }

  rng {

  }

  disks {
    ide {
      dynamic "ide0" {
        for_each = try(each.value.disk_bus, "ide") == "ide" ? [1] : []
        content {
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
      }
      ide1 {
        cdrom {
          iso = try(each.value.iso_installation, each.value.target_node.iso_installation)
        }
      }
      dynamic "ide2" {
        for_each = try(each.value.disk_bus, "ide") == "ide" && try(each.value.data_disk_size, null) != null ? [1] : []
        content {
          disk {
            backup     = false
            size       = each.value.data_disk_size
            emulatessd = true
            format     = "raw"
            storage    = each.value.disk_pool
            asyncio    = "io_uring"
            discard    = true
          }
        }
      }
    }
    dynamic "scsi" {
      for_each = try(each.value.disk_bus, "ide") == "scsi" ? [1] : []
      content {
        scsi0 {
          disk {
            backup     = false
            size       = each.value.disk_size
            emulatessd = true
            format     = "raw"
            storage    = each.value.disk_pool
            asyncio    = "io_uring"
            discard    = true
            serial     = try(each.value.disk_serial, null)
          }
        }
        dynamic "scsi1" {
          for_each = try(each.value.data_disk_size, null) != null ? [1] : []
          content {
            disk {
              backup     = false
              size       = each.value.data_disk_size
              emulatessd = true
              format     = "raw"
              storage    = each.value.disk_pool
              asyncio    = "io_uring"
              discard    = true
              serial     = try(each.value.data_disk_serial, null)
            }
          }
        }
      }
    }
  }

  efidisk {
    efitype           = "4m"
    storage           = each.value.disk_pool
    pre_enrolled_keys = false # Leave setup mode available for Talos Secure Boot key enrollment.
  }

  lifecycle {
    prevent_destroy = true
  }
}
