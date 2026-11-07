locals {
  cluster_vlan        = 70
  cluster_dhcp_server = "CLUSTER-DHCP"
  cluster_dns         = "192.168.210.2"
  cluster_hostname    = "kubelab"
  cluster_domain      = "vandeneede.org"
  intel_schematic     = "efe06b1b353c64e5582b00831867f8ec55580190d78f48b206c681b5c5a0b683"
  amd_schematic       = "ef4cc080b257a0f42c868da1c889990319f5244024c6e710a7211779ef5989ba"
  rpi_schematic       = "6deb61c88f80e8c9393a672ae93ee5d67364db0f120b8bd21de1e5025a921653"
  chonk_schematics = {
    controlplane = "c23d16533980fd972f96a79cc22130404615c16de18f43da4a40d801d4fe8d6a"
    worker       = "179a44da7532036d61547766f0272bf27283fa431dbf38614191c9116311a17c"
  }
  proxmox_nodes = {
    SOUTHPARK = {
      node_name        = "SOUTHPARK"
      iso_installation = "local:iso/nocloud-amd64-secureboot.iso"
    }
    CHONK = {
      node_name        = "CHONK"
      iso_installation = null # Each new VM selects its existing role-specific ISO.
    }
  }
  cluster_vms = {
    KUBE-001 = {
      hostname          = "kube001.vandeneede.org"
      ip_address        = "10.70.0.101"
      controlplane      = true
      proxmox           = false
      disk_device       = "/dev/sda"
      network_interface = "end0"
      talos_image       = "${local.rpi_schematic}:v${var.talos_version}"
    }
    KUBE-003 = {
      hostname          = "kube003.vandeneede.org"
      ip_address        = "10.70.0.103"
      controlplane      = true
      proxmox           = true
      target_node       = local.proxmox_nodes.SOUTHPARK
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/${local.intel_schematic}:v${var.talos_version}"
    }
    KUBE-004 = {
      hostname                 = "kube004.vandeneede.org"
      ip_address               = "10.70.0.104"
      controlplane             = true
      proxmox                  = true
      target_node              = local.proxmox_nodes.CHONK
      memory                   = 4096
      cores                    = 2
      vm_state                 = var.chonk_vm_state
      disk_pool                = var.chonk_disk_pool
      disk_size                = "32G"
      disk_bus                 = "scsi"
      disk_serial              = "kube004-os"
      boot                     = "order=scsi0;ide1;net0"
      disk_device              = "/dev/sda"
      network_interface        = "eth0"
      iso_installation         = "local:iso/controlplane_secureboot.iso"
      talos_image              = "factory.talos.dev/nocloud-installer-secureboot/${local.chonk_schematics.controlplane}:v${var.talos_version}"
      publish_cluster_endpoint = var.chonk_publish_controlplane_endpoint
    }
    KUBE-102 = {
      hostname          = "kube102.vandeneede.org"
      ip_address        = "10.70.0.112"
      controlplane      = false
      proxmox           = true
      target_node       = local.proxmox_nodes.SOUTHPARK
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      data_disk_size    = "100G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/${local.intel_schematic}:v${var.talos_version}"
    }
    KUBE-103 = {
      # All functions: RTX 3060 VGA (.0) and HDMI audio (.1), isolated IOMMU group 16.
      gpu_pci_mapping = "chonk-rtx3060"
      # Stable vendor/product IDs; both adapters were verified on CHONK.
      usb_devices = {
        zigbee  = "10c4:ea60"
        printer = "1a86:7523"
      }
      # Preserve the provider's existing startup/shutdown defaults during PCI updates.
      startup_shutdown = {
        order            = -1
        shutdown_timeout = -1
        startup_delay    = -1
      }
      hostname          = "kube103.vandeneede.org"
      ip_address        = "10.70.0.113"
      controlplane      = false
      proxmox           = true
      target_node       = local.proxmox_nodes.CHONK
      memory            = 40960
      cores             = 8
      vm_state          = var.chonk_vm_state
      disk_pool         = var.chonk_disk_pool
      disk_size         = "32G"
      disk_bus          = "scsi"
      disk_serial       = "kube103-os"
      data_disk_size    = "500G"
      data_disk_serial  = "kube103-longhorn"
      boot              = "order=scsi0;ide1;net0"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      iso_installation  = "local:iso/worker_secureboot.iso"
      talos_image       = "factory.talos.dev/nocloud-installer-secureboot/${local.chonk_schematics.worker}:v${var.talos_version}"
    }
  }
}
