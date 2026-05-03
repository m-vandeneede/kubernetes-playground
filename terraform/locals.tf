locals {
  cluster_vlan        = 70
  cluster_dhcp_server = "CLUSTER-DHCP"
  cluster_dns         = "192.168.210.2"
  cluster_hostname    = "kubelab"
  cluster_domain      = "vandeneede.org"
  intel_schematic     = "efe06b1b353c64e5582b00831867f8ec55580190d78f48b206c681b5c5a0b683"
  amd_schematic       = "ef4cc080b257a0f42c868da1c889990319f5244024c6e710a7211779ef5989ba"
  rpi_schematic       = "6deb61c88f80e8c9393a672ae93ee5d67364db0f120b8bd21de1e5025a921653"
  proxmox_nodes = {
    CREDIGREE = {
      node_name        = "CREDIGREE"
      iso_installation = "fast:iso/nocloud-amd64-secureboot.iso"
    }
    SOUTHPARK = {
      node_name        = "SOUTHPARK"
      iso_installation = "local:iso/nocloud-amd64-secureboot.iso"
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
    KUBE-002 = {
      hostname          = "kube002.vandeneede.org"
      ip_address        = "10.70.0.102"
      controlplane      = true
      proxmox           = true
      target_node       = local.proxmox_nodes.CREDIGREE
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/${local.amd_schematic}:v${var.talos_version}"
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
    KUBE-101 = {
      hostname          = "kube101.vandeneede.org"
      ip_address        = "10.70.0.111"
      controlplane      = false
      proxmox           = true
      target_node       = local.proxmox_nodes.CREDIGREE
      memory            = 2048
      cores             = 2
      disk_pool         = "fast"
      disk_size         = "10G"
      data_disk_size    = "100G"
      disk_device       = "/dev/sda"
      network_interface = "eth0"
      talos_image       = "factory.talos.dev/nocloud-installer/${local.amd_schematic}:v${var.talos_version}"
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
  }
}
